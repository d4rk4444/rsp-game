# Rock-Scissors-Paper Game dApp
      
This project is a decentralized rock-paper-scissors game that runs on a smart contract on the Binance Smart Chain blockchain and accepts BUSD and BNB tokens. The game also includes a 3% commission that goes towards improving the further development of the project and ensuring fair play. Chainlink VRF is used for randomizing the outcome.   
     
## Game Description
The game consists of two participants - a player and a bot. The player chooses one of three options: rock, scissors, or paper. The game's outcome is determined by the rules:

Rock beats scissors (rock crushes scissors)
Scissors beat paper (scissors cut paper)
Paper beats rock (paper covers rock)

The player who wins receives their stake back minus the 3% commission, as well as the stake of the losing participant. If the participants choose the same option, the player receives their stake back minus the 3% commission.   
     
## Technical Details
The game's results are saved on the blockchain, ensuring transparency and reliability.

The game is written in Solidity and launched on the Binance Smart Chain blockchain. Vue.js and Web3.js are used for the frontend to interact with the smart contract. Hardhat and Remix IDE are used for developing and testing the smart contract. Chainlink VRF (Verifiable Random Function) is used to randomize the game's outcome, ensuring a high level of trust in the game and guaranteeing fairness for all participants.

## Project Launch
1) Clone the repository
```bash
git clone https://github.com/d4rk4444/rsp-game.git
```
2) Install dependencies
```bash
cd /rsp-game
npm i
```
3) Launch the project
```bash
npm run dev
```
