// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title A Sample raffle Contract
 * @author Sarvesh Agarwal
 * @notice This contract is creating a sample raffle/lottery.
 * @dev Implements chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughEntranceFee();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numberOfPlayers, uint256 raffleState);
    error Raffle__TransferFailed();
    error Raffle__NotOpen();

    /**
     * Type declearations
     */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of the interval of the lottery
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimestamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_RaffleState;

    /**
     * Events
     */
    event RaffleEntered(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        s_lastTimestamp = block.timestamp;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_RaffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFee();
        }
        if (s_RaffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev this is the Function chainlink automation node will call
     * TO see when to perform upkeep
     * Following should be true
     * 1. Time interval between raffle has passed
     * 2. Raffle should be in open State
     * 3. Contract should has some eth
     * 4. (Implicit) Subscription is funded with link
     */
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        upkeepNeeded = (s_lastTimestamp - block.timestamp >= i_interval) &&( s_RaffleState == RaffleState.OPEN)
            && address(this).balance>0 && s_players.length>0;
    }

    function performUpkeep() public {
        (bool upkeepNeed,) = checkUpkeep("");
        if (!upkeepNeed) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_RaffleState));
        }
        s_RaffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    //CEI- Checks, Effects,Interactions
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 winnerIndex = _randomWords[0] % s_players.length;
        address payable winnerPlayer = s_players[winnerIndex];
        s_recentWinner = winnerPlayer;
        s_RaffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        (bool success,) = winnerPlayer.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winnerPlayer);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
