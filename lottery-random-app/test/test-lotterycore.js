const LotteryData = artifacts.require('LotteryData')
const LotteryCore = artifacts.require('LotteryCore')

contract('Test LotteryCore', (accounts) => {
    let lotteryData, lotteryCore

    beforeEach('create instance', async () => {
        lotteryData = await LotteryData.deployed()
        lotteryCore = await LotteryCore.deployed()
    })

    it('test accounts[0] is admin', async () => {
        await lotteryCore.addAdmin(accounts[1], { from: accounts[0] })
        let isAdmin = await lotteryCore.hasRole(accounts[1], "admin")
        assert(isAdmin, `${accounts[0]} is not admin`)
    })

    it('create lottery', async () => {
        let lotteryLength = await lotteryData.getLotteriesLength()
        lotteryLength = lotteryLength.toNumber()
        await lotteryCore.createLottery(`newLottery${lotteryLength}`)
        let lottery = await lotteryData.lotteries(lotteryLength)
        // console.info(lottery)
        assert(lottery[0] === `newLottery${lotteryLength}`, 'create lottery error')
    })

    it('add lottery prize', async () => {
        let lotteryLength = await lotteryData.getLotteriesLength()
        let lotteryId = lotteryLength.toNumber() - 1

        // 新增4件奖品，概率倒数分别为 5、10、15、20，对应概率分别为（20%、10%、6.67%、5%）
        for (let i = 0; i < 4; i++) {
            await lotteryCore.addLotteryPrize(lotteryId, `prize${i}`, i+1, (i+1)*5)
        }

        await lotteryCore.startLottery(lotteryId)

        let j = 0
        let LCM = 60 // 最小公倍数
        for (let i = 0; i < 4; i++) {
            let prize = await lotteryData.getLotteryPrizeInfo(lotteryId, i)
            assert(prize[0] === `prize${i}`, 'prize name') 
            assert(prize[1].toNumber() === i + 1, 'prize amount')
            assert(prize[3].toNumber() === (i + 1) * 5)
            for (let k = 0; k < LCM / ((i + 1) * 5); k++, j++) {
                assert(prize[5][k].toNumber() === j, 'prize winProb array')
            }
        }
    })

    // 测试用户抽奖 合约keccak256方法暂未找到合适测试工具
    it('user draw', async () => {
        let lotteryLength = await lotteryData.getLotteriesLength()
        let lotteryId = lotteryLength.toNumber() - 1

        for (let i = 1; i < accounts.length; i++) {
            let res = await lotteryCore.userDraw(lotteryId, {from: accounts[i]})

            for (let j = 0; j < res.receipt.logs.length; j++) {
                let log = res.receipt.logs[j];
                let drawInfo = {
                    hash: log.topics[1],
                    random: log.topics[2],
                    randomRes: log.topics[3]
                }
                if (log.logIndex == 0) { // 用户抽奖信息
                    console.info('---------- user draw info ------------')
                    console.info('hash', drawInfo.hash)
                    console.info('random', drawInfo.random)
                    console.info('randomRes', drawInfo.randomRes)
                    console.info('---------- user draw info end ------------')
                } else if (log.logIndex == 1) { // 用户中奖信息
                    // let convertStr = drawInfo.hash + accounts[i] + (i-1)
                    console.info('---------- user prize info ------------')
                    console.info('sender', log.topics[1])
                    console.info('lotteryId', log.topics[2])
                    console.info('prizeno', log.topics[3])
                    console.info('---------- user prize info end ------------')
                }
            }
        }
    })
})

