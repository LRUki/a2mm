import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";

const TEN_TO_18 = Math.pow(10, 18);
// helper functions for testing
const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);

//TODO: the following three functions are copy-pasted and then slightly adapted for javascript. Should we instead perhaps just call on the smart contract functions and use their outputs, since we would have unit tested them anyway?
function quantityOfYForX(x: number, y: number, dx: number) {
    return dx * 997 * y / (x * 1000 + dx * 997);
}

function quantityOfXForY(x: number, y: number, dy: number){
    return quantityOfYForX(y, x, dy);
}

function whatPrecision(x: number) {
    let xStr = x.toString();
    if (xStr[0] == '0') {
        let zerosAfterPoint = 0;
        for (let i = 2; xStr[i] == '0'; ++i) {
            zerosAfterPoint++;
        }
        return -zerosAfterPoint - 2;
    }

    let nonZerosBeforePoint = 0;
    for (let i = 0; xStr[i] != '.' && i < xStr.length; ++i) {
        nonZerosBeforePoint++;
    }
    return nonZerosBeforePoint - 2;
}

function calculateRatio(arrX: number, arrY: number, ammX: number, ammY: number) {
    let ratio;
    if (ammX == 0) {
        let xGain = quantityOfXForY(arrX, arrY, ammY);
        ratio = (arrY + ammY) / (arrX - xGain);
    } else {
        let yGain = quantityOfYForX(arrX, arrY, ammX);
        ratio = (arrY - yGain) / (arrX + ammX);
    }
    return ratio;
}

describe("==================================== Arbitrage ====================================", function () {
    before(async function () {
        const sharedFunctionAddress = await deployContract("SharedFunctions");
        this.Arbitrage = await ethers.getContractFactory("Arbitrage", {
            libraries: { SharedFunctions: sharedFunctionAddress },
        });
    });
    beforeEach(async function () {
        this.arbitrage = await this.Arbitrage.deploy();
        await this.arbitrage.deployed();
    });

    it("Flash loan is required when we hold no Y", async function () {
        const amm = await this.arbitrage.arbitrageWrapper(
            [
                toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
                toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
                toStringMap([500 * TEN_TO_18, 200 * TEN_TO_18]),
                toStringMap([50 * TEN_TO_18, 10 * TEN_TO_18]),
            ],
            `${0}`
        );
        expect(amm[1].toString()).to.not.equal('0');
    });

    it("Arbitrage fails when only one AMM supplied", async function () {
        //TODO: how do we do this test? I want to make sure that it fails because only one AMM was passed
        try {
            await this.arbitrage.arbitrageWrapper(
                [
                    toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
                ],
                `${0.0031 * TEN_TO_18}`
            );
        } catch (error) {
            console.log(error);
        }
    });

    it("Arbitrage runs when exactly two AMMs supplied (edge case)", async function () {
        await this.arbitrage.arbitrageWrapper(
            [
                toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
                toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
            ],
            `${0.0031 * TEN_TO_18}`
        );
    });

    it("No arbitrage opportunity - nothing sent anywhere", async function () {
        let ammsArr = [
            toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
            toStringMap([0.2 * TEN_TO_18, 0.3 * TEN_TO_18]),
            toStringMap([4 * TEN_TO_18, 6 * TEN_TO_18]),
            toStringMap([2 * TEN_TO_18, 3 * TEN_TO_18]),
        ]
        const amm = await this.arbitrage.arbitrageWrapper(
            ammsArr,
            `${0.0031 * TEN_TO_18}`
        );

        for (let i = 0; i < ammsArr.length; i++) {
            expect(amm[0][i].x.toString()).to.equal('0');
            expect(amm[0][i].y.toString()).to.equal('0');
        }
        expect(amm[1].toString()).to.equal('0');
    });

    it("Holding lots of Y means no flash loan required:", async function () {
        const amm = await this.arbitrage.arbitrageWrapper(
            [
                toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
                toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
                toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
            ],
            `${100 * TEN_TO_18}`
        );
        expect(amm[1].toString()).to.equal('0');
    });

    it("Ratios Y/X about equal after arbitrage done", async function () {
        let ammsArr = [
            toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
            toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
        ];

        const amm = await this.arbitrage.arbitrageWrapper(
            ammsArr,
            `${0.31 * TEN_TO_18}`
        );

        let firstRatio = calculateRatio(Number(ammsArr[0][0]), Number(ammsArr[0][1]), Number(amm[0][0].x), Number(amm[0][0].y));
        for (let i = 1; i < ammsArr.length; i++) {
            expect(Math.abs(calculateRatio(Number(ammsArr[i][0]), Number(ammsArr[i][1]), Number(amm[0][i].x), Number(amm[0][i].y)) - firstRatio)).to.lessThan(Math.pow(10, whatPrecision(firstRatio)));
        }
    });

    it("amounts of Y sent to AMMs = amount of Y held + Flash loan", async function () {
        let amountOfYHeld = 0.000000031 * TEN_TO_18;
        let ammsArr = [
            toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
            toStringMap([5 * TEN_TO_18, 2 * TEN_TO_18]),
            toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
        ];
        const amm = await this.arbitrage.arbitrageWrapper(
            ammsArr, `${amountOfYHeld}`
        );

        let ySum = 0;
        for (let i = 0; i < ammsArr.length; i++) {
            ySum += Number(amm[0][i].y.toString());
        }
        // oddly enough, the inaccuracy here comes from javascript's 'Number' instead of from solidity
        expect((Number(amm[1].toString()) + amountOfYHeld)).to.approximately(ySum, 1000);
    });
});
