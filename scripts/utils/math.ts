import assert from "assert";

export const TEN_TO_18 = Math.pow(10, 18);
export const TEN_TO_9 = Math.pow(10, 9);

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

export function quantityOfYForX(x: bigint, y: bigint, dx: bigint) {
  return (dx * BigInt(997) * y) / (x * BigInt(1000) + dx * BigInt(997));
}

export async function quantityOfXForY(x: bigint, y: bigint, dy: bigint) {
  return await quantityOfYForX(y, x, dy);
}

//TODO: replace this with the function below to use bigint instead of Number
//changa all the related caller too (is whatPrecision needed?)
export async function calculateRatio(
  arrX: number,
  arrY: number,
  ammX: number,
  ammY: number
) {
  let ratio;
  if (ammX == 0) {
    let xGain = await quantityOfXForY(BigInt(arrX), BigInt(arrY), BigInt(ammY));
    ratio = (arrY + ammY) / (arrX - Number(xGain));
  } else {
    let yGain = await quantityOfYForX(BigInt(arrX), BigInt(arrY), BigInt(ammX));
    ratio = (arrY - Number(yGain)) / (arrX + ammX);
  }
  return ratio;
}

// export function calculateRatio(
//   arrX: bigint,
//   arrY: bigint,
//   ammX: bigint,
//   ammY: bigint
// ): bigint {
//   let ratio;
//   if (ammX.toString() == "0") {
//     let xGain = quantityOfXForY(BigInt(arrX), BigInt(arrY), BigInt(ammY));
//     ratio = (arrY + ammY) / (arrX - xGain);
//   } else {
//     let yGain = quantityOfYForX(BigInt(arrX), BigInt(arrY), BigInt(ammX));
//     ratio = (arrY - yGain) / (arrX + ammX);
//   }
//   return ratio;
// }
