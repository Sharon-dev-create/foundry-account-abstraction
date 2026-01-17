// SPDX-License-Identifier

pragma solidity ^0.8.14;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/ethereum/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {
    Transaction, MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
// Foundry Devops
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

contract ZkMinimalAccountTest is Test, ZkSyncChainChecker {
    using MessageHashUtils for bytes32;

    ZkMinimalAccount zkMinimalAccount;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    address randomUser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        zkMinimalAccount = new ZkMinimalAccount();
        zkMinimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(zkMinimalAccount), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(zkMinimalAccount.owner(), dest, 113, value, functionData);

        // Act
        vm.prank(zkMinimalAccount.owner());
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(usdc.balanceOf(address(zkMinimalAccount)), AMOUNT);
    }

    function testThatANonOwnerCantExecuteCommands() public {
        // Arrange 
        address dest = address(usdc);
        address nonOwner = address(0x1234);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(zkMinimalAccount.owner(), dest, 113, value, functionData);


        // Act / Assert
        vm.prank(nonOwner);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderOrOwner.selector);
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

    }

    function testCanExecuteTransaction() public {}

    function testZkValidateTransaction() public onlyZkSync {
        // Arrange 
        address dest = address(usdc);
        address nonOwner = address(0x1234);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

         Transaction memory transaction =
            _createUnsignedTransaction(zkMinimalAccount.owner(), dest, 113, value, functionData);
        transaction = _signTransaction(transaction);
        // We need to call the validate transaction function and sign the transaction
        
        //Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    ///  HELPER FUNCTIONS  ///
    function _signTransaction(Transaction memory transaction) internal view returns(Transaction memory){
    //encode the transaction hash
       bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
       bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();
       uint8 v;
       bytes32 r;
       bytes32 s;
       uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
       
       (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
       Transaction memory signedTransaction = transaction;
       signedTransaction.signature = abi.encodePacked(r, s, v);
    }

    function _createUnsignedTransaction(
        address from,
        address to,
        uint8 transactionType,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(zkMinimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType, //Type 113 (0x71)
            from: uint256(uint160(from)), // need to convert from address to uint256
            to: uint256(uint160(to)), // the conversion is because address are much smaller and dont fit in the whole 256 bits
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}
