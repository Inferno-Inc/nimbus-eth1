# Nimbus
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# XXX: when all but a relative few dozen, say, GeneralStateTests run, remove this,
# but for now, this enables some CI use before that to prevent regressions. In the
# separate file here because it would otherwise just distract. Could use all sorts
# of O(1) or O(log n) lookup structures, or be more careful to only initialize the
# table once, but notion's that it should shrink reasonable quickly and disappear,
# being mostly used for short-term regression prevention.
func allowedFailingGeneralStateTest*(folder, name: string): bool =
  let allowedFailingGeneralStateTests = @[
    "CrashingTransaction.json",
    "callcallcallcode_001.json",
    "callcallcallcode_001.json",
    "callcallcallcode_001_SuicideEnd.json",
    "callcallcallcode_001_SuicideMiddle.json",
    "callcallcode_01.json",
    "callcallcode_01_SuicideEnd.json",
    "callcallcodecall_010.json",
    "callcallcodecall_010_SuicideEnd.json",
    "callcallcodecall_010_SuicideMiddle.json",
    "callcallcodecallcode_011.json",
    "callcallcodecallcode_011_SuicideEnd.json",
    "callcallcodecallcode_011_SuicideMiddle.json",
    "callcodecall_10_SuicideEnd.json",
    "callcodecallcall_100.json",
    "callcodecallcall_100_SuicideEnd.json",
    "callcodecallcall_100_SuicideMiddle.json",
    "callcodecallcallcode_101.json",
    "callcodecallcallcode_101_SuicideEnd.json",
    "callcodecallcallcode_101_SuicideMiddle.json",
    "callcodecallcode_11.json",
    "callcodecallcode_11_SuicideEnd.json",
    "callcodecallcodecall_110.json",
    "callcodecallcodecall_110_SuicideEnd.json",
    "callcodecallcodecall_110_SuicideMiddle.json",
    "callcodecallcodecallcode_111.json",
    "callcodecallcodecallcode_111_SuicideEnd.json",
    "callcodecallcodecallcode_111_SuicideMiddle.json",
    "CREATE_AcreateB_BSuicide_BStore.json",
    "CREATE_ContractSuicideDuringInit.json",
    "CREATE_ContractSuicideDuringInit_ThenStoreThenReturn.json",
    "CREATE_ContractSuicideDuringInit_WithValue.json",
    "CREATE_ContractSuicideDuringInit_WithValueToItself.json",
    "CREATE_EContractCreateEContractInInit_Tr.json",
    "CREATE_EContract_ThenCALLToNonExistentAcc.json",
    "CREATE_EmptyContract.json",
    "CREATE_EmptyContractAndCallIt_0wei.json",
    "CREATE_EmptyContractAndCallIt_1wei.json",
    "CREATE_EmptyContractWithBalance.json",
    "CREATE_empty000CreateinInitCode_Transaction.json",
    "TransactionCollisionToEmptyButCode.json",
    "TransactionCollisionToEmptyButNonce.json",
    "CallLoseGasOOG.json",
    "CallcodeLoseGasOOG.json",
    "callOutput1.json",
    "callOutput2.json",
    "callOutput3.json",
    "callOutput3Fail.json",
    "callOutput3partial.json",
    "callOutput3partialFail.json",
    "callcodeOutput1.json",
    "callcodeOutput2.json",
    "callcodeOutput3.json",
    "callcodeOutput3Fail.json",
    "callcodeOutput3partial.json",
    "callcodeOutput3partialFail.json",
    "deleagateCallAfterValueTransfer.json",
    "delegatecallInInitcodeToEmptyContract.json",
    "delegatecallInInitcodeToExistingContract.json",
    "delegatecallSenderCheck.json",
    "delegatecallValueCheck.json",
    "delegatecodeDynamicCode.json",
    "delegatecodeDynamicCode2SelfCall.json",
    "RawCreateFailGasValueTransfer2.json",
    "RawCreateGas.json",
    "RawCreateGasMemory.json",
    "RawCreateGasValueTransfer.json",
    "RawCreateGasValueTransferMemory.json",
    "createContractViaContract.json",
    "createContractViaContractOOGInitCode.json",
    "createContractViaTransactionCost53000.json",
    "CallContractToCreateContractAndCallItOOG.json",
    "CallContractToCreateContractNoCash.json",
    "CallContractToCreateContractOOG.json",
    "CallContractToCreateContractOOGBonusGas.json",
    "CallContractToCreateContractWhichWouldCreateContractIfCalled.json",
    "CallContractToCreateContractWhichWouldCreateContractInInitCode.json",
    "CallTheContractToCreateEmptyContract.json",
    "OutOfGasContractCreation.json",
    "OutOfGasPrefundedContractCreation.json",
    "TransactionCreateAutoSuicideContract.json",
    "callDataCopyOffset.json",
    "codeCopyOffset.json",
    "CALLCODEEcrecover0_0input.json",
    "CALLCODEEcrecover1.json",
    "CALLCODEEcrecover2.json",
    "CALLCODEEcrecover80.json",
    "CALLCODEEcrecoverR_prefixed0.json",
    "CALLCODEEcrecoverV_prefixedf0.json",
    "CALLCODERipemd160_2.json",
    "CALLCODERipemd160_3.json",
    "CALLCODERipemd160_3_postfixed0.json",
    "CALLCODERipemd160_3_prefixed0.json",
    "CALLCODESha256_2.json",
    "CALLCODESha256_3.json",
    "CALLCODESha256_3_postfix0.json",
    "CALLCODESha256_3_prefix0.json",
    "CallEcrecover0_0input.json",
    "CallEcrecover1.json",
    "CallEcrecover2.json",
    "CallEcrecover80.json",
    "CallEcrecoverCheckLengthWrongV.json",
    "CallEcrecoverR_prefixed0.json",
    "CallRipemd160_2.json",
    "CallRipemd160_3.json",
    "CallRipemd160_3_postfixed0.json",
    "CallRipemd160_3_prefixed0.json",
    "CallSha256_2.json",
    "CallSha256_3.json",
    "CallSha256_3_postfix0.json",
    "CallSha256_3_prefix0.json",
    "randomStatetest14.json",
    "randomStatetest184.json",
    "randomStatetest307.json",
    "randomStatetest368.json",
    "randomStatetest85.json",
    #"randomStatetest579.json",
    "randomStatetest643.json",
    "randomStatetest644.json",
    "randomStatetest645.json",
    "randomStatetest646.json",
    "randomStatetest248.json",
    "refundSuicide50procentCap.json",
    "refund_CallToSuicideNoStorage.json",
    "refund_CallToSuicideStorage.json",
    "refund_CallToSuicideTwice.json",
    "refund_multimpleSuicide.json",
    "refund_singleSuicide.json",
    "RevertOpcodeCalls.json",
    "RevertOpcodeDirectCall.json",
    "RevertOpcodeInCallsOnNonEmptyReturnData.json",
    "RevertOpcodeInInit.json",
    "RevertOpcodeMultipleSubCalls.json",
    "RevertOpcodeReturn.json",
    "RevertOpcodeWithBigOutputInInit.json",
    "RevertPrefound.json",
    "RevertPrefoundEmpty.json",
    "TouchToEmptyAccountRevert3.json",
    "TestContractSuicide.json",
    "TestCryptographicFunctions.json",
    "tx_e1c174e2.json",
    "ABAcallsSuicide1.json",
    "CreateHashCollision.json",
    "createNameRegistrator.json",
    "createNameRegistratorZeroMem.json",
    "createNameRegistratorZeroMem2.json",
    "createNameRegistratorZeroMemExpansion.json",
    "suicideCoinbase.json",
    "suicideSendEtherPostDeath.json",
    "testRandomTest.json",
    "EmptyTransaction2.json",
    "EmptyTransaction3.json",
    "Opcodes_TransactionInit.json",
    "SuicidesAndInternlCallSuicidesBonusGasAtCall.json",
    "SuicidesAndInternlCallSuicidesSuccess.json",
    "SuicidesMixingCoinbase.json",
    "TransactionFromCoinbaseHittingBlockGasLimit1.json",
    "TransactionSendingToEmpty.json",
    "createNameRegistratorPerTxsNotEnoughGasAfter.json",
    "createNameRegistratorPerTxsNotEnoughGasAt.json",
    "createNameRegistratorPerTxsNotEnoughGasBefore.json",
    "delegatecallAfterTransition.json",
    "delegatecallAtTransition.json",
    "delegatecallBeforeTransition.json",
    # 2018-12-07:
    # 2019-02-07:
    "makeMoney.json",
    # 2019-02-15:
    "callWithHighValueAndGasOOG.json",
    "callcodeWithHighValueAndGasOOG.json",
    "randomStatetest101.json",
    "randomStatetest116.json",
    "randomStatetest237.json",
    "randomStatetest7.json",
    # 2019-02-17:
    "RawCreateFailGasValueTransfer.json",
    "createInitFail_OOGduringInit.json",
    "NewGasPriceForCodes.json",
    "NewGasPriceForCodesWithMemExpandingCalls.json",
    "NonZeroValue_CALLCODE_ToNonNonZeroBalance.json",
    "pairingTest.json",
    "pointAdd.json",
    "pointAddTrunc.json",
    "pointMulAdd.json",
    "pointMulAdd2.json",
    # most likely to crash:
    "createNameRegistratorOOG_MemExpansionOOV.json",
    "createNameRegistratorOutOfMemoryBonds0.json",
    "createNameRegistratorOutOfMemoryBonds1.json",
    "ContractCreationSpam.json",
    "Call1024OOG.json",
    "Call1024PreCalls.json",
    "CallRecursiveBombPreCall.json",
    "Delegatecall1024.json",
    "Delegatecall1024OOG.json",
    "recursiveCreate.json",
    "recursiveCreateReturnValue.json",
    "JUMPDEST_Attack.json",
    "JUMPDEST_AttackwithJump.json",
    "ABAcalls1.json",
    "ABAcalls2.json",
    "CallRecursiveBomb0.json",
    "CallRecursiveBomb0_OOG_atMaxCallDepth.json",
    "CallRecursiveBomb1.json",
    "CallRecursiveBomb2.json",
    "CallRecursiveBombLog.json",
    "CallRecursiveBombLog2.json",
    "Call1024BalanceTooLow.json"
  ]
  result = name in allowedFailingGeneralStateTests
