const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const {
  abi,
  bytecode,
} = require("usingtellor/artifacts/contracts/TellorPlayground.sol/TellorPlayground.json");
const h = require("usingtellor/test/helpers/helpers.js");

describe("Function testing", function () {
  let tellorOracle, audioCoin, crowdFund;
  const albumID = 1;
  abiCoder = new ethers.utils.AbiCoder();

  // Set up Tellor Playground Oracle and SnapshotVoting
  beforeEach(async function () {
    const TellorOracle = await ethers.getContractFactory(abi, bytecode);
    tellorOracle = await TellorOracle.deploy();
    await tellorOracle.deployed();

    const AudioCoin = await ethers.getContractFactory("AudioCoin");
    audioCoin = await AudioCoin.deploy();
    await audioCoin.deployed();

    const CrowdFund = await ethers.getContractFactory("CrowdFund");
    crowdFund = await CrowdFund.deploy(tellorOracle.address, audioCoin.address);
    await crowdFund.deployed();

    queryDataArgs = abiCoder.encode(
      ["address", "uint256"],
      [crowdFund.address, albumID]
    );

    queryData = abiCoder.encode(
      ["string", "bytes"],
      ["albumDrop", queryDataArgs]
    );

    queryID = ethers.utils.keccak256(queryData);

    [owner, addr1, addr2] = await ethers.getSigners();
    valuesEncoded = abiCoder.encode(["bool", "address"], [true, addr1.address]);
  });

  it("Should submit and read to oracle", async function () {

    
    // submit value takes 4 args : queryId, value, nonce and queryData
    await tellorOracle.submitValue(queryID, valuesEncoded, 0, queryData);
    // await crowdFund.didHappen(1)
    // expect(balanceOf(band).to.equal(1000 tokens);
    let retrievedVal = await crowdFund.getCurrentValue(queryID);
    decoded = abiCoder.decode(["bool", "address"], retrievedVal[1]);
    expect(String(decoded)).to.equal(String([true, addr1.address]));
  });
});
