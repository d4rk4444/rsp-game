// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RSPGame is VRFConsumerBaseV2, Ownable {
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
    bytes32 keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint32 callbackGasLimit = 200000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint64 subscriptionId = 2557;

    IERC20 private token;
    address public tokenAddress = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee; //BUSD
    uint32 public gameNumber = 1;
    uint32 public feeGame = 3;
    uint public minAmountBet = 0.01 ether;
    uint public maxAmountBet = 1 ether;
    uint public amountFee;
    uint public minAmountTokenBet = 0.1 ether;
    uint public maxAmountTokenBet = 10 ether;
    uint public amountFeeToken;

    constructor() VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        token = IERC20(tokenAddress);
    }

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords; // oracle number
        uint32 numberGame; // game number
    }

    struct GameStatus {
        address payable player;
        uint8 gameType; //0 - BNB, 1 - BUSD
        uint8 userProperty; //0 - stone 1 - scissors 2 - paper
        uint256 amountBet;
        uint256 requestId;
        bool isLive;
        address winner;
    }

    mapping(uint256 => RequestStatus) public s_requests; // requestId --> requestStatus
    mapping(uint256 => GameStatus) public s_games; // numberGame --> gameStatus

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

    /**
        Property:
        0 - stone
        1 - scissors
        2 - paper
     */
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
            gameType: 0,
            userProperty: userProperty,
            amountBet: msg.value,
            requestId: requestId,
            isLive: true,
            winner: 0x0000000000000000000000000000000000000000
        });

        gameNumber++;
    }

    function createTokenGame(uint256 amountBet, uint8 userProperty) external {
        require(token.transferFrom(msg.sender, address(this), amountBet), "Failed to transfer tokens to contract");
        require(amountBet >= minAmountTokenBet && amountBet <= maxAmountTokenBet, "amount bet < mininal bet or > maximal bet");
        require(userProperty >= 0 && userProperty <= 2, "property error");
        require(token.balanceOf(address(this)) > amountBet * 2, "balance of the contract is not enough");

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
            gameType: 1,
            userProperty: userProperty,
            amountBet: amountBet,
            requestId: requestId,
            isLive: true,
            winner: 0x0000000000000000000000000000000000000000
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
        GameStatus memory gameStatus = s_games[numberGame];
        uint fee = gameStatus.amountBet / 100 * feeGame;
        uint8 oracleProperty = uint8(_randomWords[0] % 3);
        uint8 userProperty = gameStatus.userProperty;
        uint amountDraw = gameStatus.amountBet - fee;
        uint amountWin = gameStatus.amountBet * 2 - fee;

        if (oracleProperty == 0 && userProperty == 1 || oracleProperty == 1 && userProperty == 2 || oracleProperty == 2 && userProperty == 0) { //loss options
            gameStatus.winner = address(this);
            emit newWin(amountDraw, address(this), numberGame);
        } else if (oracleProperty == userProperty) { //draw options
            if (gameStatus.gameType == 0) {
                gameStatus.player.transfer(amountDraw);
            } else if (gameStatus.gameType == 1) {
                token.transfer(gameStatus.player, amountDraw);
            }
            emit newWin(amountDraw, gameStatus.winner, numberGame);
        } else if (oracleProperty == 0 && userProperty == 2 || oracleProperty == 1 && userProperty == 0 || oracleProperty == 2 && userProperty == 1) { //win options
            gameStatus.winner = address(gameStatus.player);
            if (gameStatus.gameType == 0) {
                gameStatus.player.transfer(amountWin);
            } else if (gameStatus.gameType == 1) {
                token.transfer(gameStatus.winner, amountWin);
            }
            emit newWin(amountWin, gameStatus.winner, numberGame);
        }
        
        s_games[numberGame].isLive = false;
        gameStatus.gameType == 0 ? amountFee += fee : amountFeeToken += fee;
    }

    function getRequestStatus(uint256 _requestId) public view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    /**
        Returns the random number of game
     */
    function getOracleNumber(uint256 _gameNumber) public view returns (uint256 oracleNumber) {
        require(_gameNumber < gameNumber, "number game not found");
        require(!s_games[_gameNumber].isLive, "game is not end");
        GameStatus memory gameStatus = s_games[_gameNumber];
        oracleNumber = s_requests[gameStatus.requestId].randomWords[0];
        return (oracleNumber);
    }

    /**
        Returns the properties of game
     */
    function getGameResult(uint256 _gameNumber) public view returns (uint8 userProperty, uint8 oracleProperty) {
        require(_gameNumber < gameNumber, "number game not found");
        require(!s_games[_gameNumber].isLive, "game is not end");
        GameStatus memory gameStatus = s_games[_gameNumber];
        RequestStatus memory requestStatus = s_requests[s_games[_gameNumber].requestId];

        return (gameStatus.userProperty, uint8(requestStatus.randomWords[0] % 3));
    }

    /**
        Deposit BNB
     */
    function deposit() external payable {
        require(msg.value > 0, "deposit amount must be greater than 0");
    }

    /**
        Withdrawal of commissions in BNB earned by a smart contract
     */
    function withdrawFee() external onlyOwner {
        payable(address(msg.sender)).transfer(amountFee);
        amountFee -= amountFee;
    }

    /**
        Withdrawal of commissions in BUSD earned by a smart contract
     */
    function withdrawFeeToken() external onlyOwner {
        require(token.transfer(address(msg.sender), amountFeeToken), "Failed to transfer tokens");
        amountFeeToken -= amountFeeToken;
    }

    /**
        Withdrawal of all BNB and BUSD is possible if there are no active games
     */
    function withdrawAll() external onlyOwner {
        require(!s_games[gameNumber-1].isLive, "the last game is not over");
        payable(address(msg.sender)).transfer(address(this).balance);
        token.transfer(address(msg.sender), token.balanceOf(address(this)));
    }
}