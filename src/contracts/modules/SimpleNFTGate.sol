// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

import {ModuleBase} from "../ModuleBase.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {ICheqModule} from "../interfaces/ICheqModule.sol";
import {ICheqRegistrar} from "../interfaces/ICheqRegistrar.sol";
import {IWriteRule, ITransferRule, IFundRule, ICashRule, IApproveRule} from "../interfaces/IWTFCRules.sol";

abstract contract SimpleNFTGate is
    IWriteRule,
    ITransferRule,
    IFundRule,
    ICashRule,
    IApproveRule
{}