import { deployContract } from './utils';

export default async function () {
  await deployContract(
    'Paymaster',
    [],
    {
      noVerify: false,
      upgradable: true,
      kind: 'uups',
      unsafeAllow: ['constructor'],
    },
    [process.env.QUOTER, process.env.GASFACTOR],
  );
}
