import { astroBin, runNodeBinary } from './package-tools.mjs';

const args = process.argv.slice(2);

runNodeBinary(astroBin, args, { cwd: process.cwd() });
