import { upgradeContract } from './utils';

export default async function () {
  await upgradeContract('Paymaster', [], {
    noVerify: false,
    upgradable: true,
    unsafeAllow: ['constructor'],
  });
}
