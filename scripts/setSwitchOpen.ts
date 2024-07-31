import { ethers } from 'hardhat';
import dotenv from 'dotenv';
// Load env file
dotenv.config();

const paymaster = {
  contractAddress: process.env.PAYMASTER,
  switch: true,
};

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.ZKLINK_RPC);
  if (!process.env.WALLET_PRIVATE_KEY) throw "⛔️ Wallet private key wasn't found in .env file!";
  const wallet = new ethers.Wallet(process.env.WALLET_PRIVATE_KEY, provider);
  if (!paymaster.contractAddress) throw "⛔️ Contract address wasn't found in .env file!";
  const contract = new ethers.Contract(
    paymaster.contractAddress,
    [
      {
        inputs: [
          {
            internalType: 'bool',
            name: '_switch',
            type: 'bool',
          },
        ],
        name: 'setAllowTokenSwitch',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
      },
    ],
    wallet,
  );

  const tx = await contract.setAllowTokenSwitch(paymaster.switch);
  console.log(`Transaction hash: ${tx.hash}`);
  await tx.wait();
  console.log(`setAllowTokenSwitch  to ${paymaster.switch}`);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
