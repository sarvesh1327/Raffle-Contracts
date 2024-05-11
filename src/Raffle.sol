// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title A Sample raffle Contract
 * @author Sarvesh Agarwal
 * @notice This contract is creating a sample raffle/lottery.
 * @dev Implements chainlink VRFv2
 */
contract Raffle {
    error Raffle__NotEnoughEntranceFee();
    error Raffle__LotteryNotOver();

    uint256 private immutable i_entranceFee;
    // @dev duration of the interval of the lottery
    uint256 private immutable i_interval;
    uint256 private immutable s_lastTimestamp;
    address payable[] private s_players;

    /**
     * Events
     */
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        s_lastTimestamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFee();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickLotteryWinner() public {
        if(block.timestamp-s_lastTimestamp<i_interval){
            revert Raffle__LotteryNotOver();
        }

    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
