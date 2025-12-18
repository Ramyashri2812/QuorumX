const {
  Client,
  AccountId,
  PrivateKey,
  ContractCreateFlow,
  ContractCallQuery,
  ContractFunctionParameters,
  Hbar
} = require("@hashgraph/sdk");
const fs = require("fs");
require("dotenv").config();

async function deployContract() {
  const myAccountId = AccountId.fromString("0.0.7476256");
  const myPrivateKey = PrivateKey.fromStringECDSA("0x63239661dee6a4a6da16db643f166a8d2d4840e3bdfc24c9429f068ad035a127");

  const client = Client.forTestnet();
  client.setOperator(myAccountId, myPrivateKey);

  console.log("Deploying EscrowMilestones contract to Hedera Testnet...");
  console.log("Account:", myAccountId.toString());

  try {
    const bytecode = fs.readFileSync("./bytecode.bin").toString();

    console.log("Creating contract...");

    const contractCreate = new ContractCreateFlow()
      .setGas(30000000)
      .setBytecode(bytecode)
      .setMaxChunks(30);

    const txResponse = await contractCreate.execute(client);
    const receipt = await txResponse.getReceipt(client);
    const contractId = receipt.contractId;

    console.log("Contract deployed successfully!");
    console.log("Contract ID:", contractId.toString());
    console.log("Transaction ID:", txResponse.transactionId.toString());
    console.log(`View on HashScan: https://hashscan.io/testnet/contract/${contractId.toString()}`);

    console.log("\nTesting contract...");
    const jobCountQuery = new ContractCallQuery()
      .setContractId(contractId)
      .setGas(100000)
      .setFunction("jobCount");

    const jobCountResult = await jobCountQuery.execute(client);
    const jobCount = jobCountResult.getUint256(0);
    console.log("Initial job count:", jobCount.toString());

    client.close();
    return contractId.toString();

  } catch (error) {
    console.error("Deployment failed:", error);
    client.close();
    throw error;
  }
}

deployContract()
  .then(contractId => {
    console.log("\nDeployment complete! Contract ID:", contractId);
    process.exit(0);
  })
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
