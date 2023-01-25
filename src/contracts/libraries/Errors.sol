// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.16;

library Errors {
    // error CannotInitImplementation();
    // error Initialized();
    // error SignatureExpired();
    // error ZeroSpender();
    // error SignatureInvalid();
    // error NotOwnerOrApproved();
    error NotRegistrar();
    // error TokenDoesNotExist();
    error NotGovernance();
    // error NotGovernanceOrEmergencyAdmin();
    // error EmergencyAdminCannotUnpause();
    // error CallerNotWhitelistedModule();
    // error CollectModuleNotWhitelisted();
    // error FollowModuleNotWhitelisted();
    // error ReferenceModuleNotWhitelisted();
    // error ProfileCreatorNotWhitelisted();
    // error NotProfileOwner();
    // error NotProfileOwnerOrDispatcher();
    // error NotDispatcher();
    // error PublicationDoesNotExist();
    // error HandleTaken();
    // error HandleLengthInvalid();
    // error HandleContainsInvalidCharacters();
    // error HandleFirstCharInvalid();
    // error ProfileImageURILengthInvalid();
    // error CallerNotFollowNFT();
    // error CallerNotCollectNFT();
    // error BlockNumberInvalid();
    // error ArrayMismatch();
    // error CannotCommentOnSelf();
    // error NotWhitelisted();
    // error InvalidParameter();

    // // Module Errors
    error InitParamsInvalid();
    // error CollectExpired();
    // error FollowInvalid();
    // error ModuleDataMismatch();
    // error FollowNotApproved();
    // error MintLimitExceeded();
    // error CollectNotAllowed();

    // MultiState Errors
    error Paused();
    error PublishingPaused();
}