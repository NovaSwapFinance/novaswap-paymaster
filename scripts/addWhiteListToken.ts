import { ethers } from 'hardhat';
import dotenv from 'dotenv';
// Load env file
dotenv.config();

const tokenInfos = {
  Paymaster: {
    contractAddress: process.env.PAYMASTER,
    tokens: [
      '0x1a1A3b2ff016332e866787B311fcB63928464509',
      '0xDa4AaEd3A53962c83B35697Cd138cc6df43aF71f',
      '0x2F8A25ac62179B31D62D7F80884AE57464699059',
      '0xC967dabf591B1f4B86CFc74996EAD065867aF19E',
    ],
    fee: [3000, 3000, 3000, 10000],
  },
};

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.ZKLINK_RPC);
  if (!process.env.WALLET_PRIVATE_KEY) throw "⛔️ Wallet private key wasn't found in .env file!";
  const wallet = new ethers.Wallet(process.env.WALLET_PRIVATE_KEY, provider);

  for (const tokenInfo of Object.values(tokenInfos)) {
    if (!tokenInfo.contractAddress) throw "⛔️ Contract address wasn't found in .env file!";
    const contract = new ethers.Contract(
      tokenInfo.contractAddress,
      [
        {
          inputs: [
            {
              internalType: 'address',
              name: '_allowedToken',
              type: 'address',
            },
            {
              internalType: 'uint24',
              name: '_fee',
              type: 'uint24',
            },
          ],
          name: 'setAllowedTokenList',
          outputs: [],
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ],
      wallet,
    );

    for (let i = 0; i < tokenInfo.tokens.length; i++) {
      const tx = await contract.setAllowedTokenList(tokenInfo.tokens[i], tokenInfo.fee[i]);
      console.log(`Transaction hash: ${tx.hash}`);
      await tx.wait();
      console.log(`setAllowedTokenList for ${tokenInfo.tokens[i]} set to ${tokenInfo.fee[i]}`);
    }
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
