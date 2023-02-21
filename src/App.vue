<template>
    <n-alert class="alert" v-if="alertVisible" :title="alertTitle" :type="alertType">{{ alertText }}</n-alert>
    <h1>rock scissors paper</h1>
    <div class="connectButton">
        <ConnectWalletButton @click="switchAccount" :address='address' :txnCount="txnCount" :dark="true">
            Connect Wallet!
            <template #pending></template>
            <template #spinner></template>
        </ConnectWalletButton>
    </div>
    <div v-if="!gameLive" class="group">
        <n-space vertical>
            <n-radio-group v-model:value="valueType" name="radiogroup" default-checked="BUSD">
            <n-radio v-for="song in types" :key="song.value" :value="song.value" :label="song.label" class="radio" />
        </n-radio-group>
            <n-input-group :style="{ width: '300px' }">
                <n-select  v-model:value="valueProperty" :options="options" placeholder="property" />
                <n-input-number v-if="valueType == 0" v-model:value="value" :style="{ width: '300px' }" placeholder="amount bet" step="0.1" min="0.1" max="1">
                    <template #suffix>BNB</template>
                </n-input-number>
                <n-input-number v-else="valueType == 1" v-model:value="value" :style="{ width: '300px' }" placeholder="amount bet" step="0.1" min="0.1" max="10">
                    <template #suffix>BUSD</template>
                </n-input-number>
            </n-input-group>
            <n-button @click="valueType == 0 ? play(valueProperty, value) : approve(valueProperty, value)" class='button' color='#333399'>Играть</n-button>
        </n-space>
    </div>
    <div v-if="gameLive">
        <n-grid :cols="7">
            <n-gi></n-gi>
            <n-gi></n-gi>
            <n-gi>
                <div class="side">
                    <p>bot</p>
                    <img v-if="!botProperty" src="./assets/question.png" alt="Image 1">
                    <img :class="{ 'img-loss': resultGame == 'win', 'img-win': resultGame == 'loss', 'img-draw': resultGame == 'draw' }" v-if="botProperty"
                        :src="`./src/assets/${botProperty}.png`" alt="Image 1">
                </div>
            </n-gi>
            <n-gi>
                <div class="center">
                    <n-avatar v-if="valueType == 0" class='avatar-value' :size="30" round src="https://cryptologos.cc/logos/bnb-bnb-logo.png"/>
                    <n-avatar v-else="valueType == 1" class='avatar-value' :size="30" round src="https://cryptologos.cc/logos/binance-usd-busd-logo.png"/>
                    <p>{{ value }}</p>
                    <p v-if="!resultGame" class="status-result">wait...</p>
                </div>
            </n-gi>
            <n-gi>
                <div class="side">
                    <p>you</p>
                    <img :class="{ 'img-win': resultGame === 'win', 'img-loss': resultGame === 'loss', 'img-draw': resultGame === 'draw' }"
                        :src="`./src/assets/${valueProperty}.png`" alt="Image 2">
                </div>
            </n-gi>
        </n-grid>
        <n-button v-if="resultGame" @click="endGame" class="button-endgame" color='#333399'>Играть еще раз</n-button>
    </div>
</template>

<script>
    import Web3 from 'web3'
    import { ConnectWalletButton, useMetaMaskWallet } from 'vue-connect-wallet'
    import { NSpace, NInputGroup, NSelect, NInputNumber, NButton, NAlert, NGrid, NGi, NAvatar, NRadioGroup, NRadio } from 'naive-ui'
    import { defineComponent, ref } from "vue";
    import ABI from '../artifacts/contracts/RSPGame.sol/RSPGame.json'
    import { abiToken } from '../public/abiToken.js'

    export default defineComponent({
        components:{
            ConnectWalletButton,
            NSpace,
            NInputGroup,
            NSelect,
            NInputNumber,
            NButton,
            NAlert,
            NGrid,
            NGi,
            NAvatar,
            NRadioGroup,
            NRadio
        },
        data() {
            return {
                web3: null,
                txnCount: 0,
                contract: '0x4CF9b49aac773b79d00826b41A08b0f218175b17',
                wallet: null,
                address: '',
                valueProperty: ref(null),
                botProperty: null,
                value: ref(0.1),
                options: [
                    { label: 'Камень', value: '0' },
                    { label: 'Ножницы', value: '1' },
                    { label: 'Бумага', value: '2' }
                ],
                valueType: ref(null),
                types: [
                    {
                        value: 0,
                        label: "BNB"
                    },
                    {
                        value: 1,
                        label: "BUSD"
                    },
                ],
                alertVisible: false,
                alertTitle: '',
                alertText: '',
                alertType: '',
                gameLive: false,
                resultGame: null,
            }
        },
        async created() {
            this.valueType = this.types[0].value;
            const wallet = useMetaMaskWallet();
            this.wallet = wallet;

            const switchOrAddChain = async() => {
                wallet.switchOrAddChain(97, {
                    chainName: 'Binance Smart Chain Testnet',
                    rpcUrls: ['https://data-seed-prebsc-1-s3.binance.org:8545'],
                    nativeCurrency: {
                        name: 'tBNB',
                        symbol: 'tBNB',
                        decimals: 18
                    },
                    blockExplorerUrls: ['https://testnet.bscscan.com']
                });
            }

            wallet.onAccountsChanged((accounts) => {
                console.log("account changed to: ", accounts[0]);
                this.address = accounts[0];
            });

            wallet.onChainChanged(async (chainId) => {
                console.log("chain changed to:", chainId);
                if (chainId != '0x61') {
                    this.showAlert('error', 'Error', 'Change chain wallet to binance testnet');
                    await switchOrAddChain();
                }
            });

            await switchOrAddChain();
            await this.connect();
        },
        methods: {
            async connect() {
                const accounts = await this.wallet.connect();
                if (typeof accounts === "string") {
                    return this.showAlert('error', 'Error', accounts);
                };
                this.address = accounts[0];
            },
            async switchAccount() {
                await this.wallet.switchAccounts();
                this.connect();
            },
            showAlert(alertType, alertTitle, alertText) {
                this.alertTitle = alertTitle;
                this.alertText = alertText;
                this.alertType = alertType;
                this.alertVisible = true;

                setTimeout(() => {
                    this.alertVisible = false
                }, 2000);
            },
            async timeout(ms) {
                return new Promise(resolve => {
                    setTimeout(() => {
                    resolve();
                    }, ms);
                });
            },
            async startGame(blockNumber, addressFrom) {
                const contract = new this.web3.eth.Contract(ABI.abi, this.contract);
                let numberGame;
                let winnerAddress;

                await contract.getPastEvents("newGame", {
                    fromBlock: blockNumber,
                    toBlock: 'latest',
                }, (error, events) => {
                    if (!error) {
                        for(let i = 0; i < events.length; i++) {
                            if (events[i].returnValues.player == this.web3.utils.toChecksumAddress(addressFrom)) {
                                numberGame = events[i].returnValues.numberGame;
                                i =  events.length;
                            }
                        }
                    } else {
                        return this.showAlert('error', 'Error', error.message);
                    }
                });
                await this.timeout(7500);

                while(true) {
                    try {
                        await this.timeout(5000);
                        const data = await contract.methods.getGameResult(
                            numberGame
                        ).call();
                        this.botProperty = data.oracleProperty;
                        break;
                    } catch (err) {};
                }
                await this.timeout(1000);

                while(true) {
                    await contract.getPastEvents("newWin", {
                        fromBlock: blockNumber,
                        toBlock: 'latest',
                    }, async(error, events) => {
                        if (!error) {
                            if (events.length > 0) {
                                for(let i = 0; i < events.length; i++) {
                                    if (events[i].returnValues.numberGame == numberGame) {
                                        winnerAddress = events[i].returnValues.winnerAddress;
                                        if (winnerAddress == this.contract) {
                                            this.resultGame = 'loss';
                                        } else if (winnerAddress == '0x0000000000000000000000000000000000000000') {
                                            this.resultGame = 'draw';
                                        } else if (winnerAddress != this.contract && winnerAddress != '0x0000000000000000000000000000000000000000') {
                                            this.resultGame = 'win';
                                        }
                                        i = events.length;
                                    }
                                }
                            }
                        } else if (error) {
                            this.showAlert('error', 'Error', error.message);
                        }
                    });
                    if (this.resultGame) break;
                }
            },
            async checkTransactionStatus(hash, typeTX) {
                while(true) {
                    const receipt = await this.web3.eth.getTransactionReceipt(hash);
                    if (receipt) {
                        if (receipt.status == true) {
                            if (typeTX == 'approve') {
                                this.showAlert('success', 'Approve success', `https://testnet.bscscan.com/tx/${hash}`);
                                this.txnCount = 0;
                            } else if (typeTX == 'game') {
                                this.showAlert('success', 'Transaction success', `https://testnet.bscscan.com/tx/${hash}`);
                                this.txnCount = 0;
                                this.gameLive = true;
                                await this.startGame(receipt.blockNumber, receipt.from);
                            }
                            break;
                        } else if (receipt.status == false) {
                            this.showAlert('error', 'Error', 'Transaction failed');
                            break;
                        }
                    } 
                    await this.timeout(2000);
                }
            },
            async play(valueProperty, value) {
                if (this.value == 0 || !this.valueProperty) {
                    return this.showAlert('warning', 'Warning', 'Choose property and bet amount');
                }

                this.web3 = new Web3(window.web3.currentProvider);
                const contract = new this.web3.eth.Contract(ABI.abi, this.contract);

                const data = await contract.methods.createGame(
                    this.web3.utils.numberToHex(value * 10**18),
                    valueProperty
                );
                const accounts = await this.wallet.getAccounts();

                await this.web3.eth.sendTransaction({
                    from: accounts[0],
                    to: this.contract,
                    value: this.web3.utils.numberToHex(value * 10**18),
                    gas: await data.estimateGas({ from: accounts[0], value: this.web3.utils.numberToHex(value * 10**18) }),
                    data: data.encodeABI()
                }, async(error, result) => {
                    if (error) {
                        return this.showAlert('error', 'Error', error.message);
                    } else {
                        this.showAlert('info', 'Transaction sent', `https://testnet.bscscan.com/tx/${result}`);
                        this.txnCount++
                        await this.checkTransactionStatus(result, 'game');
                    }
                });
            },
            async playToken(valueProperty, value) {
                const contract = new this.web3.eth.Contract(ABI.abi, this.contract);
                const data = await contract.methods.createTokenGame(
                    this.web3.utils.numberToHex(value * 10**18),
                    valueProperty
                );

                const accounts = await this.wallet.getAccounts();

                await this.web3.eth.sendTransaction({
                    from: accounts[0],
                    to: this.contract,
                    value: null,
                    gas: await data.estimateGas({ from: accounts[0] }),
                    data: data.encodeABI()
                }, async(error, result) => {
                    if (error) {
                        return this.showAlert('error', 'Error', error.message);
                    } else {
                        this.showAlert('info', 'Transaction sent', `https://testnet.bscscan.com/tx/${result}`);
                        this.txnCount++
                        await this.checkTransactionStatus(result, 'game');
                    }
                });
            },
            async approve(valueProperty, value) {
                if (this.value == 0 || !this.valueProperty) {
                    return this.showAlert('warning', 'Warning', 'Choose property and bet amount');
                }

                this.web3 = new Web3(window.web3.currentProvider);
                const accounts = await this.wallet.getAccounts();
                const contractToken = new this.web3.eth.Contract(abiToken, '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee');

                const allowance = await contractToken.methods.allowance(
                    accounts[0],
                    this.contract
                ).call();


                if (allowance < (value * 10**18)) {
                    const dataApprove = await contractToken.methods.approve(
                        this.contract,
                        '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
                    );

                    await this.web3.eth.sendTransaction({
                        from: accounts[0],
                        to: '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee',
                        value: null,
                        gas: await dataApprove.estimateGas({ from: accounts[0] }),
                        data: dataApprove.encodeABI()
                    }, async(error, result) => {
                        if (error) {
                            return this.showAlert('error', 'Error', error.message);
                        } else {
                            this.showAlert('info', 'Approve sent', `https://testnet.bscscan.com/tx/${result}`);
                            this.txnCount++
                            await this.checkTransactionStatus(result, 'approve');
                        }
                    });
                }

                while(true) {
                    const allowance = await contractToken.methods.allowance(
                        accounts[0],
                        this.contract
                    ).call();

                    if (allowance > value * 10**18) {
                        await this.playToken(valueProperty, value);
                        break;
                    }
                }
            },
            endGame() {
                this.gameLive = false;
                this.botProperty = null;
                this.resultGame = null;
            }
        }
    });
</script>


<style>
    @import url('https://fonts.googleapis.com/css2?family=Josefin+Sans:wght@700&display=swap');
    @import url('https://fonts.googleapis.com/css2?family=Barlow&family=Josefin+Sans:wght@700&display=swap');
    body {
        background-color: #666699;
    }

    h1 {
        font-family: 'Josefin Sans', sans-serif;
        font-size: 65px;
        text-align: center;
    }

    .connectButton {
        position: absolute;
        top: 50px;
        right: 75px;
    }

    .alert {
        position: absolute;
        top: 25px;
        left: 10px;
        width: '500px';
    }

    .button {
        width: 100%;
    }

    .group {
        display: flex;
        justify-content: center;
        align-items: center;
    }

    .side {
        height: 200px;
        /*background-color: rgba(0, 128, 0, 0.12);*/
        text-align: center;
    }

    .center {
        height: 200px;
        /*background-color: rgba(0, 128, 0, 0.24);*/
        display: flex;
        flex-direction: row;
        align-items: center;
        justify-content: center;
    }

    img {
        width: 130px;
    }

    .img-win {
        box-shadow: 0 0 20px 5px #33FF33;
    }

    .img-loss {
        box-shadow: 0 0 20px 5px #FF3333;
    }

    .img-draw {
        box-shadow: 0 0 20px 5px #FF9900;
    }

    p {
        font-family: 'Barlow', sans-serif;
        display: block;
        font-size: 20px;
        font-weight: bold;
    }

    .avatar-value {
        display: inline-block;
        vertical-align: middle;
    }

    .avatar-value img {
        display: block;
        width: 30px;
        height: 30px;
        border-radius: 50%;
    }

    .avatar-value + p {
        display: inline-block;
        margin-left: 10px;
        vertical-align: middle;
    }

    .status-result {
        position: absolute;
        bottom: 65%;
        left: 50%;
        transform: translateX(-50%);
    }

    .button-endgame{
        display: block;
        margin: 0 auto;
    }

    .radio {

    }
</style>
