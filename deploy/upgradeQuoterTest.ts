import { upgradeContract } from './utils';

export default async function () {
  await upgradeContract('QuoterTest', [], {
    noVerify: false,
    upgradable: true,
    unsafeAllow: ['constructor'],
  });
}
