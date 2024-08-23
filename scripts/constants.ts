export const HEX_ADDRESS = '0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39';
export const HSIM_ADDRESS = '0x8BD3d1472A656e312E94fB1BbdD599B8C51D18e3';
export const HEDRON_ADDRESS = '0x3819f64f282bf135d62168C1e513280dAF905e06';
export const DAI_ADDRESS = '0x6B175474E89094C44Da98b954EedeAC495271d0F'; 

export const DAI_HOLDER = '0xBF293D5138a2a1BA407B43672643434C43827179';
export const HEX_HOLDER = '0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8'

export const UNISWAP_FACTORY_ADDRESS = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f' // uniswap

export const ROUTER_ADDRESS = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'

export const PAYOUT_RESOLUTION = 1000000000000000000n; // loan interest decimal resolution
export const PAYOUT_START_DAY = 800;

const scaler = 1000000000000000000n
export const FARM_EMISSION_SCHEDULE: [bigint, bigint, bigint] = [350000000n * scaler, 250000000n * scaler, 150000000n * scaler]
export const TEAM_EMISSION_SCHEDULE: [bigint, bigint, bigint] = [116000000n * scaler, 83000000n * scaler, 51000000n * scaler]
export const TEAM_EMISSION: bigint = 250000000n * scaler
export const POOL_POINT_SCHEDULE = [
  // year 1
  1000,
  1750,
  2500,
  // year 2
  1000,
  1500,
  2000,
  2500,
  3000,
  // year 3
  0,
  1000,
  1500,
  2000,
  2500,
  3000,
]


export const ERROR_CODES = {
  A000: 'Cannot revoke a collateralized stake',
  A001: 'Cannot burn more tokens than minted against this stake',
  A002: 'Cannot mint more tokens than extractable HEX',
  A003: 'Token have already matured. Use redeemHEXTimeTokens instead.',
  A004: 'HSI index address mismatch',
  A005: 'HSIM: Cannot call stakeEnd until minted tokens are retired or mature',
  A006: 'Provided fCollateralIndex does match the current collateral index',
  A007: 'HSIM: Insufficient contract HEX balance to facilitate redemption for this maturity. You must first end stakes to free up HEX for redemption.',
  A008: 'HSIM: Insufficient maturity tokens to facilitate stake',
  A009: 'HSIM: token has not matured',
  A010: 'HEX transfer failed',
  A011: 'HDRN: HSI index address mismatch',
  A012: 'Index out of bounds',
  A013: 'You\'ve already minted tokens against this stake with a different maturity',
  A014: 'You cannot mint HEX time tokens on a fully served stake',
  A015: 'Tokens maturity must be on or after end stake',
  A016: 'HEX transfer failed',
  A017: 'Maturity cannot be more than 714 days after stake end',
  A018: 'Stake must have minted HTTs in order to call hexStakeEndColateral',
  A019: 'Stake must not have minted HTTs in order to call hexStakeEnd',
  A020: 'Cannot unlock an collateralized stake until it\'s fully served',
  A021: 'Maturity tokens must mature in the future',
  A022: 'Only the stake owner can unlock a fully served collateralized stake before redemption',
  A023: 'Amount must be greater than 0',
  A024: 'Retirement amount must be greater than 0',
  A025: 'Only the team account can call this function',
  A026: 'HEXTimeToken.collectFees: You do not have any fees to deposits',
  A027: 'End time must be greater than start time',
  A028: 'add: pool already exists',
  A029: 'add: too many alloc points',
  A030: 'withdraw: not good',
  A031: 'add: too many alloc points',
  A032: 'add: can\'t set totalAllocPoint to 0',
  A033: 'Maturity not found',
  A034: 'you arleady have a stake in this maturity. call feeMineIncrease instead.',
  A035: 'Actuator.feeMineStart: you don\'t arleady have a stake in this maturity. call feeMineStart instead.',
  A036: 'Caller is not allowed',
  A037: 'withdraw: not good',
  A038: 'Invalid farm pool address',
  A039: 'Caller is not allowed',
  A040: 'Deposit Amount must be greater than 0',
  A041: 'Withdrawal amount must be greater than 0',
  A042: 'Caller is not allowed',
  A043: 'Deposit amount must be greater than 0',
  A044: 'Farm Deposits must be greater than 0 to collect ACTR emissions',
  A045: 'Redemption day must be in the future',
  A046: 'Staked days must be at least 180 days to mint HEX time tokens whose maturity is before end stake',
  A047: 'Redemption day must be set to a later day in the future',
}

export const ACCOUNTS = [
  {
    address: '0x05fAc7c07BD99d267fD4fD53Db063a16400A8E50',
    privateKey: '0x9d5bf32b2413e1e3d19121346bc7d6ed7b14de364ec54c3a51cae7f1404e52ed',
  },
  {
    address: '0x93Af16E5F278678BB2345dE70fEAfea238BE831A',
    privateKey: '0xd7ef74b7aa88170fcea09d2211830b5b2117c7b277861e4f7ad1f17d4468e0c3',
  },
  {
    address: '0x8313a5ACd04E64eA58c1803D509DF79723a4B4df',
    privateKey: '0x9f89a1efdcbc77997f1b5baea3665908e61880a6b9b57ea2c3969a68ec11e511',
  },
  {
    address: '0x18Ef7BE687b69e7763C5C8Cb91E5760A9119b2E2',
    privateKey: '0x6864cc8854824b73e2a5a5c35476c4539b2ff5f789770a94056ae59e477d6e05',
  },
  {
    address: '0x2481a35dDb8F739f9c0C547f4acF1b7FC170De08',
    privateKey: 'efb68fed77ecf6e6be371c631b5d2b41c3f1918076e49918858575e95cafd8cf',
  },
  {
    address: '0xae51A9DF0cDd1d5B91a8bc4E8e18578e238a4A3f',
    privateKey: 'b30b4aad21c3b41b23902f86962b27830f15341ddae6ac729d71a86022359536',
  },
  {
    address: '0x8843A7eB647244a75816856c7d865643E9710fa1',
    privateKey: 'c002505ed5bfe202cf8bfb83a4a91bb5778e8767483b1638d57a7bcba65289cd',
  },
  {
    address: '0x2416E0e35F3eD617b699a7A6fd9cccB568E01782',
    privateKey: '4ceb68c52a708be1f9fd9ebff6517397a1d0a3a3e1ed0c79e9fac90bb70bc434',
  },
]


export const payouts = [
0n,         0n,   1103571n,   2043014n,   3009069n,   3786558n,
4540908n,   5453694n,   6170555n,   6876573n,   7574939n,   8263658n,
8950771n,   9600289n,  10224239n,  10873371n,  11547552n,  12238368n,
12946207n,  13808408n,  14467543n,  15227873n,  16038588n,  16812971n,
17599319n,  18415642n,  19221020n,  20132291n,  20980144n,  21923046n,
23045893n,  24046064n,  24964259n,  25886126n,  26861042n,  27816612n,
28850816n,  29854327n,  30909636n,  31898196n,  32924435n,  33964802n,
34993254n,  36058826n,  37155871n,  38242615n,  39426167n,  40756388n,
41885367n,  43035972n,  44210931n,  45454614n,  46658637n,  47940288n,
49160294n,  50399134n,  51539819n,  52693289n,  53957904n,  55281941n,
56561854n,  57858560n,  59177400n,  60528563n,  61806116n,  63106402n,
64406152n,  65825768n,  67243799n,  68895729n,  70933416n,  72513354n,
77386390n,  79756483n,  82811584n,  88864941n,  92711825n,  94403010n,
97323821n,  98840742n, 100424135n, 102413273n, 104576139n, 106161216n,
107779034n, 109558490n, 111191362n, 112854990n, 114513061n, 116193696n,
117895442n, 119606243n, 121333886n, 123083752n, 124843874n, 126624529n,
128548661n, 130393279n, 132507338n, 134347450n,
]