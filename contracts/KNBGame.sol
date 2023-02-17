// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KNBGame is VRFConsumerBaseV2, Ownable {
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
    bytes32 keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint64 subscriptionId = 2557;

    constructor() VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords; // oracle number
        uint32 numberGame; // game number
    }

    struct GameStatus {
        address payable player;
        uint8 userProperty;
        uint256 amountBet;
        uint256 requestId;
        bool isLive;
        address payable winner;
    }

    mapping(uint256 => RequestStatus) public s_requests; // requestId --> requestStatus
    mapping(uint256 => GameStatus) public s_games; // numberGame --> gameStatus

    uint32 public gameNumber = 1;
    uint32 public feeGame = 3;
    uint public minAmountBet = 0.001 ether;
    uint public maxAmountBet = 1 ether;
    uint private amountFee;

    event newGame(uint amountBet, address player, uint32 numberGame);
    event newWin(uint amountWin, address winnerAddress, uint32 numberGame);

    function changeKeyHash(bytes32 _keyHash) external onlyOwner {
        keyHash = _keyHash;
    }

    function changeCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    function changeSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }

    function changeFee(uint32 _feeGame) external onlyOwner {
        require(_feeGame >= 0 && _feeGame <= 10, "fee < 0 or > 10");
        feeGame = _feeGame;
    }

    /** Property:
        0 - stone
        1 - scissors
        2 - paper
    **/
    function createGame(uint256 amountBet, uint8 userProperty) external payable {
        require(msg.value >= minAmountBet && msg.value <= maxAmountBet, "amount bet < mininal bet or > maximal bet");
        require(msg.value == amountBet, "value != amount bet");
        require(userProperty >= 0 && userProperty <= 2, "property error");
        require(address(this).balance > amountBet * 2, "balance of the contract is not enough");

        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false,
            numberGame: gameNumber
        });

        emit newGame(amountBet, msg.sender, gameNumber);

        s_games[gameNumber] = GameStatus({
            player: payable(msg.sender),
            userProperty: userProperty,
            amountBet: msg.value,
            requestId: requestId,
            isLive: true,
            winner: payable(0x0000000000000000000000000000000000000000)
        });

        gameNumber++;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        uint32 numberGame = s_requests[_requestId].numberGame;
        uint fee = s_games[numberGame].amountBet / 100 * feeGame;
        uint8 oracleProperty = uint8(_randomWords[0] % 3);
        uint8 userProperty = s_games[numberGame].userProperty;

        if (oracleProperty == 0 && userProperty == 1 || oracleProperty == 1 && userProperty == 2 || oracleProperty == 2 && userProperty == 0) { //loss options
            s_games[numberGame].winner = payable(address(this));
            emit newWin(s_games[numberGame].amountBet, address(this), numberGame);
        } else if (oracleProperty == userProperty) { //draw options
            s_games[numberGame].player.transfer(s_games[numberGame].amountBet - fee);
            emit newWin(0, s_games[numberGame].winner, numberGame);
        } else if (oracleProperty == 0 && userProperty == 2 || oracleProperty == 1 && userProperty == 0 || oracleProperty == 2 && userProperty == 1) { //win options
            s_games[numberGame].winner = s_games[numberGame].player;
            uint amountWin = s_games[numberGame].amountBet * 2 - fee;
            s_games[numberGame].player.transfer(amountWin);
            emit newWin(amountWin, s_games[numberGame].player, numberGame);
        }
        
        s_games[numberGame].isLive = false;
        amountFee += fee;
    }

    function getRequestStatus(uint256 _requestId) public view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    function getGameStatus(uint256 _gameNumber) public view returns (address payable player, uint256 amountBet, uint256 requestId, bool isLive, address payable winner) {
        require(_gameNumber < gameNumber, "number game not found");
        GameStatus memory gameStatus = s_games[_gameNumber];
        return (gameStatus.player, gameStatus.amountBet, gameStatus.requestId, gameStatus.isLive, gameStatus.winner);
    }

    function getOracleNumber(uint256 _gameNumber) public view returns (uint256 oracleNumber) {
        require(_gameNumber < gameNumber, "number game not found");
        require(!s_games[_gameNumber].isLive, "game is not end");
        GameStatus memory gameStatus = s_games[_gameNumber];
        oracleNumber = s_requests[gameStatus.requestId].randomWords[0];
        return (oracleNumber);
    }

    function getGameProperty(uint256 _gameNumber) public view returns (uint8 userProperty, uint8 oracleProperty) {
        require(_gameNumber < gameNumber, "number game not found");
        require(!s_games[_gameNumber].isLive, "game is not end");
        GameStatus memory gameStatus = s_games[_gameNumber];
        RequestStatus memory requestStatus = s_requests[s_games[_gameNumber].requestId];

        return (gameStatus.userProperty, uint8(requestStatus.randomWords[0] % 3));
    }

    function deposit() public payable {
        require(msg.value > 0, "deposit amount must be greater than 0");
    }

    function withdraw() external onlyOwner {
        address owner = owner();
        payable(owner).transfer(amountFee);
    }
}