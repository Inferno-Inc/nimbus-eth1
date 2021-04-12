# Nimbus
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

when not defined(vm2_enabled):
  {.fatal: "Flags \"vm2_enabled\" must be defined"}
when defined(evmc_enabled):
  {.fatal: "Flags \"evmc_enabled\" and \"vm2_enabled\" are mutually exclusive"}

import
  chronicles, strformat, macros, options, times,
  sets, eth/[common, keys],
  ../constants, ../errors,
  ./interpreter/[v2opcode_values, gas_meter, v2gas_costs, v2forks],
  ./code_stream, ./memory_defs, ./v2message, ./stack, ./v2types, ./v2state,
  ../db/[accounts_cache, db_chain],
  ../utils/header, ./v2precompiles,
  ./transaction_tracer, ../utils

when defined(chronicles_log_level):
  import stew/byteutils

logScope:
  topics = "vm computation"

template getCoinbase*(c: Computation): EthAddress =
  block:
    c.vmState.coinbase

template getTimestamp*(c: Computation): int64 =
  block:
    c.vmState.timestamp.toUnix

template getBlockNumber*(c: Computation): Uint256 =
  block:
    c.vmState.blockNumber.blockNumberToVmWord

template getDifficulty*(c: Computation): DifficultyInt =
  block:
    c.vmState.difficulty

template getGasLimit*(c: Computation): GasInt =
  block:
    c.vmState.gasLimit

template getChainId*(c: Computation): uint =
  block:
    c.vmState.chaindb.config.chainId.uint

template getOrigin*(c: Computation): EthAddress =
  block:
    c.vmState.txOrigin

template getGasPrice*(c: Computation): GasInt =
  block:
    c.vmState.txGasPrice

template getBlockHash*(c: Computation, blockNumber: Uint256): Hash256 =
  block:
    c.vmState.getAncestorHash(blockNumber.vmWordToBlockNumber)

template accountExists*(c: Computation, address: EthAddress): bool =
  block:
    if c.fork >= FkSpurious:
      not c.vmState.readOnlyStateDB.isDeadAccount(address)
    else:
      c.vmState.readOnlyStateDB.accountExists(address)

template getStorage*(c: Computation, slot: Uint256): Uint256 =
  block:
    c.vmState.readOnlyStateDB.getStorage(c.msg.contractAddress, slot)

template getBalance*(c: Computation, address: EthAddress): Uint256 =
  block:
    c.vmState.readOnlyStateDB.getBalance(address)

template getCodeSize*(c: Computation, address: EthAddress): uint =
  block:
    uint(c.vmState.readOnlyStateDB.getCodeSize(address))

template getCodeHash*(c: Computation, address: EthAddress): Hash256 =
  block:
    let db = c.vmState.readOnlyStateDB
    if not db.accountExists(address) or db.isEmptyAccount(address):
      default(Hash256)
    else:
      db.getCodeHash(address)

template selfDestruct*(c: Computation, address: EthAddress) =
  block:
    c.execSelfDestruct(address)

template getCode*(c: Computation, address: EthAddress): seq[byte] =
  block:
    c.vmState.readOnlyStateDB.getCode(address)

proc generateContractAddress(c: Computation, salt: Uint256): EthAddress =
  if c.msg.kind == evmcCreate:
    let creationNonce = c.vmState.readOnlyStateDb().getNonce(c.msg.sender)
    result = generateAddress(c.msg.sender, creationNonce)
  else:
    result = generateSafeAddress(c.msg.sender, salt, c.msg.data)

import stew/byteutils

proc newComputation*(vmState: BaseVMState, message: Message, salt= 0.u256): Computation =
  new result
  result.vmState = vmState
  result.msg = message
  result.memory = Memory()
  result.stack = newStack()
  result.returnStack = @[]
  result.gasMeter.init(message.gas)
  result.touchedAccounts = initHashSet[EthAddress]()
  result.suicides = initHashSet[EthAddress]()

  if result.msg.isCreate():
    result.msg.contractAddress = result.generateContractAddress(salt)
    result.code = newCodeStream(message.data)
    message.data = @[]
  else:
    result.code = newCodeStream(vmState.readOnlyStateDb.getCode(message.codeAddress))


template gasCosts*(c: Computation): untyped =
  c.vmState.gasCosts

template fork*(c: Computation): untyped =
  c.vmState.fork

proc isOriginComputation*(c: Computation): bool =
  # Is this computation the computation initiated by a transaction
  c.msg.sender == c.vmState.txOrigin

template isSuccess*(c: Computation): bool =
  c.error.isNil

template isError*(c: Computation): bool =
  not c.isSuccess

func shouldBurnGas*(c: Computation): bool =
  c.isError and c.error.burnsGas

proc isSuicided*(c: Computation, address: EthAddress): bool =
  result = address in c.suicides

proc snapshot*(c: Computation) =
  c.savePoint = c.vmState.accountDb.beginSavePoint()

proc commit*(c: Computation) =
  c.vmState.accountDb.commit(c.savePoint)

proc dispose*(c: Computation) {.inline.} =
  c.vmState.accountDb.safeDispose(c.savePoint)
  c.savePoint = nil

proc rollback*(c: Computation) =
  c.vmState.accountDb.rollback(c.savePoint)

proc setError*(c: Computation, msg: string, burnsGas = false) {.inline.} =
  c.error = Error(info: msg, burnsGas: burnsGas)

proc writeContract*(c: Computation, fork: Fork): bool {.gcsafe.} =
  result = true

  let contractCode = c.output
  if contractCode.len == 0: return

  if fork >= FkSpurious and contractCode.len >= EIP170_CODE_SIZE_LIMIT:
    debug "Contract code size exceeds EIP170", limit=EIP170_CODE_SIZE_LIMIT, actual=contractCode.len
    return false

  let storageAddr = c.msg.contractAddress
  if c.isSuicided(storageAddr): return

  let gasParams = GasParams(kind: Create, cr_memLength: contractCode.len)
  let codeCost = c.gasCosts[Create].c_handler(0.u256, gasParams).gasCost
  if c.gasMeter.gasRemaining >= codeCost:
    c.gasMeter.consumeGas(codeCost, reason = "Write contract code for CREATE")
    c.vmState.mutateStateDb:
      db.setCode(storageAddr, contractCode)
    result = true
  else:
    if fork < FkHomestead or fork >= FkByzantium: c.output = @[]
    result = false

proc initAddress(x: int): EthAddress {.compileTime.} = result[19] = x.byte
const ripemdAddr = initAddress(3)
proc executeOpcodes*(c: Computation) {.gcsafe.}

proc beforeExecCall(c: Computation) =
  c.snapshot()
  if c.msg.kind == evmcCall:
    c.vmState.mutateStateDb:
      db.subBalance(c.msg.sender, c.msg.value)
      db.addBalance(c.msg.contractAddress, c.msg.value)

proc afterExecCall(c: Computation) =
  ## Collect all of the accounts that *may* need to be deleted based on EIP161
  ## https://github.com/ethereum/EIPs/blob/master/EIPS/eip-161.md
  ## also see: https://github.com/ethereum/EIPs/issues/716

  if c.isError or c.fork >= FKByzantium:
    if c.msg.contractAddress == ripemdAddr:
      # Special case to account for geth+parity bug
      c.vmState.touchedAccounts.incl c.msg.contractAddress

  if c.isSuccess:
    c.commit()
    c.touchedAccounts.incl c.msg.contractAddress
  else:
    c.rollback()

proc beforeExecCreate(c: Computation): bool =
  c.vmState.mutateStateDB:
    db.incNonce(c.msg.sender)

    # We add this to the access list _before_ taking a snapshot.
    # Even if the creation fails, the access-list change should not be rolled back
    # EIP2929
    if c.fork >= FkBerlin:
      db.accessList(c.msg.contractAddress)

  c.snapshot()

  if c.vmState.readOnlyStateDb().hasCodeOrNonce(c.msg.contractAddress):
    c.setError("Address collision when creating contract address={c.msg.contractAddress.toHex}", true)
    c.rollback()
    return true

  c.vmState.mutateStateDb:
    db.subBalance(c.msg.sender, c.msg.value)
    db.addBalance(c.msg.contractAddress, c.msg.value)
    db.clearStorage(c.msg.contractAddress)
    if c.fork >= FkSpurious:
      # EIP161 nonce incrementation
      db.incNonce(c.msg.contractAddress)

  return false

proc afterExecCreate(c: Computation) =
  if c.isSuccess:
    let fork = c.fork
    let contractFailed = not c.writeContract(fork)
    if contractFailed and fork >= FkHomestead:
      c.setError(&"writeContract failed, depth={c.msg.depth}", true)

  if c.isSuccess:
    c.commit()
  else:
    c.rollback()

proc beforeExec(c: Computation): bool =
  if not c.msg.isCreate:
    c.beforeExecCall()
    false
  else:
    c.beforeExecCreate()

proc afterExec(c: Computation) =
  if not c.msg.isCreate:
    c.afterExecCall()
  else:
    c.afterExecCreate()

template chainTo*(c, toChild: Computation, after: untyped) =
  c.child = toChild
  c.continuation = proc() =
    after

proc execCallOrCreateAux(c: var Computation) {.noinline.} =
  # Perform recursion with minimum-size stack per level.  The exception
  # handling is very subtle.  Each call to `snapshot` must have a corresponding
  # `dispose` on exception.  To minimise this proc's stackframe, `defer` is
  # moved to the outermost proc only.  `{.noinline.}` is also used to make
  # extra sure they stay separate.  `c` is a `var` parameter at every level of
  # recursion, so the outermost proc sees every change to `c`, which is why `c`
  # is updated instead of using `let`.  On exception, the outermost `defer`
  # walks the `c.parent` chain to call `dispose` on each `c`.
  if c.beforeExec():
    return
  c.executeOpcodes()
  while not c.continuation.isNil:
    # Parent and child refs are updated and cleared so as to avoid circular
    # refs (like a double-linked list) or dangling refs (to finished child).
    (c.child, c, c.parent) = (nil.Computation, c.child, c)
    execCallOrCreateAux(c)
    c.dispose()
    (c.parent, c) = (nil.Computation, c.parent)
    (c.continuation)()
    c.executeOpcodes()
  c.afterExec()

proc execCallOrCreate*(cParam: Computation) =
  var c = cParam
  defer:
    while not c.isNil:
      c.dispose()
      c = c.parent
  execCallOrCreateAux(c)

proc merge*(c, child: Computation) =
  c.logEntries.add child.logEntries
  c.gasMeter.refundGas(child.gasMeter.gasRefunded)
  c.suicides.incl child.suicides
  c.touchedAccounts.incl child.touchedAccounts

proc execSelfDestruct*(c: Computation, beneficiary: EthAddress) =
  c.vmState.mutateStateDB:
    let
      localBalance = c.getBalance(c.msg.contractAddress)
      beneficiaryBalance = c.getBalance(beneficiary)

    # Transfer to beneficiary
    db.setBalance(beneficiary, localBalance + beneficiaryBalance)

    # Zero the balance of the address being deleted.
    # This must come after sending to beneficiary in case the
    # contract named itself as the beneficiary.
    db.setBalance(c.msg.contractAddress, 0.u256)

    trace "SELFDESTRUCT",
      contractAddress = c.msg.contractAddress.toHex,
      localBalance = localBalance.toString,
      beneficiary = beneficiary.toHex

  c.touchedAccounts.incl beneficiary
  # Register the account to be deleted
  c.suicides.incl(c.msg.contractAddress)

proc addLogEntry*(c: Computation, log: Log) {.inline.} =
  c.logEntries.add(log)

proc getGasRefund*(c: Computation): GasInt =
  if c.isSuccess:
    result = c.gasMeter.gasRefunded

proc refundSelfDestruct*(c: Computation) =
  let cost = gasFees[c.fork][RefundSelfDestruct]
  c.gasMeter.refundGas(cost * c.suicides.len)

proc tracingEnabled*(c: Computation): bool {.inline.} =
  EnableTracing in c.vmState.tracer.flags

proc traceOpCodeStarted*(c: Computation, op: Op): int {.inline.} =
  c.vmState.tracer.traceOpCodeStarted(c, op)

proc traceOpCodeEnded*(c: Computation, op: Op, lastIndex: int) {.inline.} =
  c.vmState.tracer.traceOpCodeEnded(c, op, lastIndex)

proc traceError*(c: Computation) {.inline.} =
  c.vmState.tracer.traceError(c)

proc prepareTracer*(c: Computation) {.inline.} =
  c.vmState.tracer.prepare(c.msg.depth)

include interpreter_dispatch
