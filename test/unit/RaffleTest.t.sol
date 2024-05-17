// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // events
    event RaffleEntered(address indexed player);

    Raffle public raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkTokenAddress;
    address public PLAYER = makeAddr("Player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee, interval, vrfCoordinator, keyHash, subscriptionId, callbackGasLimit, linkTokenAddress) =
            helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializeWithRaffleOpenState() external view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughEntranceFeeIsPaid() external {
        //Arrange
        vm.prank(PLAYER);

        //Act/assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);

        //Act
        raffle.enterRaffle{value: 0.02 ether}();

        //Assert
        assertEq(raffle.getTotalPlayers(), 1);
        assert(raffle.getRafflePlayer(0) == PLAYER);
    }

    function testEmitEventOnEntranceOfPlayer() public {
        // Arrange
        vm.prank(PLAYER);
        //Act/Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: 0.02 ether}();
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.02 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testCantEnterRaffleWhenRaffleIsInCalculatingState() public raffleEntered {
        //Arrange--> via raffleEntered

        //Act
        raffle.performUpkeep();

        //Assert
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.02 ether}();
    }

    ////////////////////////
    ////// Check Upkeep ///
    //////////////////////

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnFalseIfRaffleNotOpen() public raffleEntered {
        // Arrange--> via raffleEntered

        //Act
        raffle.performUpkeep();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnFalseIfNotEnoughTimePass() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: 0.02 ether}();
        vm.warp(block.timestamp + interval - 2);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnTrueWhenAllThingsPass() public raffleEntered {
        // Arrange--> via raffleEntered

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /////////////////////////
    ///// Perform Upkeep ////
    /////////////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
        // Arrange--> via raffleEntered

        //Act/assert
        raffle.performUpkeep();
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        // Act/Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep();
    }

    function testPerformUpkeepShouldChangeRaffleStateAndEmitRequestId() public raffleEntered {
        //arrange--> via raffle Entered

        //Act
        vm.recordLogs();
        raffle.performUpkeep();
        Vm.Log[] memory enteries = vm.getRecordedLogs();
        bytes32 requestId = enteries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /////////////////////////
    ///fullfillrandomWords///
    /////////////////////////

    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // arrange--> via raffleEntered
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }
}
