import assert from "assert";

export const TEN_TO_18 = Math.pow(10, 18);

// helper functions for testing
export const toStringMap = (nums: number[]) => nums.map((num) => `${num}`);

export function whatPrecision(x: number, sf: number) {
    assert(x != 0);
    let xStr = x.toString();
    if (xStr[0] == "0") {
        let zerosAfterPoint = 0;
        for (let i = 2; xStr[i] == "0"; ++i) {
            zerosAfterPoint++;
        }
        return -zerosAfterPoint - sf;
    }

    let nonZerosBeforePoint = 0;
    for (let i = 0; xStr[i] != "." && i < xStr.length; ++i) {
        nonZerosBeforePoint++;
    }
    return nonZerosBeforePoint - sf;
}

export async function quantityOfYForX(x: bigint, y: bigint, dx: bigint) {
    return Number(dx * BigInt(997) * y / (x * BigInt(1000) + dx * BigInt(997)));
}

export async function quantityOfXForY(x: bigint, y: bigint, dy: bigint) {
    return await quantityOfYForX(y, x, dy);
}

export async function calculateRatio(
    arrX: number,
    arrY: number,
    ammX: number,
    ammY: number
) {
    let ratio;
    if (ammX == 0) {
        let xGain = await quantityOfXForY(
            BigInt(arrX),
            BigInt(arrY),
            BigInt(ammY)
        );
        ratio = (arrY + ammY) / (arrX - xGain);
    } else {
        let yGain = await quantityOfYForX(
            BigInt(arrX),
            BigInt(arrY),
            BigInt(ammX)
        );
        ratio = (arrY - yGain) / (arrX + ammX);
    }
    return ratio;
}
