import { ethers } from "hardhat";
import { expect } from "chai";
import deployContract from "../scripts/utils/deploy";

const TEN_TO_18 = Math.pow(10, 18);
// helper functions for testing
const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);
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

    it("Arbitrage runs 1", async function () {
        //TODO: test this properly
        const amm = await this.arbitrage.arbitrageWrapper(
            [
                toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
                toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
                toStringMap([500 * TEN_TO_18, 200 * TEN_TO_18]),
                toStringMap([50 * TEN_TO_18, 10 * TEN_TO_18]),
            ],
            `${0.000031 * TEN_TO_18}`
        );
        console.log(amm.toString(), "ARBITRAGE 1");
    });

    it("Arbitrage runs 2", async function () {
        //TODO: test this properly
        const amm = await this.arbitrage.arbitrageWrapper(
            [
                toStringMap([3 * TEN_TO_18, 2 * TEN_TO_18]),
                toStringMap([2 * TEN_TO_18, 4 * TEN_TO_18]),
                toStringMap([0.5 * TEN_TO_18, 0.2 * TEN_TO_18]),
            ],
            `${31 * TEN_TO_18}`
        );
        console.log(amm.toString(), "ARBITRAGE 2");
    });
});
