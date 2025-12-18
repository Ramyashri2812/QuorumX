const solc = require("solc");
const fs = require("fs");
const path = require("path");

function compileContract() {
  console.log("Compiling EscrowMilestones.sol...");

  const contractPath = path.join(__dirname, "freelancer.sol");
  const source = fs.readFileSync(contractPath, "utf8");

  const input = {
    language: "Solidity",
    sources: {
      "freelancer.sol": {
        content: source,
      },
    },
    settings: {
      outputSelection: {
        "*": {
          "*": ["abi", "evm.bytecode"],
        },
      },
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  };

  const output = JSON.parse(solc.compile(JSON.stringify(input)));

  if (output.errors) {
    output.errors.forEach((err) => {
      console.error(err.formattedMessage);
    });

    const hasErrors = output.errors.some(err => err.severity === "error");
    if (hasErrors) {
      throw new Error("Compilation failed");
    }
  }

  const contract = output.contracts["freelancer.sol"]["EscrowMilestones"];
  const bytecode = contract.evm.bytecode.object;
  const abi = contract.abi;

  fs.writeFileSync("bytecode.bin", bytecode);
  console.log("Bytecode saved to bytecode.bin");

  fs.writeFileSync("abi.json", JSON.stringify(abi, null, 2));
  console.log("ABI saved to abi.json");

  console.log(`Bytecode size: ${bytecode.length / 2} bytes`);

  return { bytecode, abi };
}

try {
  compileContract();
  console.log("\nCompilation successful!");
} catch (error) {
  console.error("Compilation failed:", error);
  process.exit(1);
}
