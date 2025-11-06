const hre = require("hardhat");

async function main() {
  console.log("Bắt đầu triển khai contract...");

  // Thông tin token
  const tokenName = "Base Token";
  const tokenSymbol = "BASE";
  const initialSupply = hre.ethers.parseEther("1000000"); // 1 triệu token ban đầu

  // Lấy signer (người triển khai)
  const [deployer] = await hre.ethers.getSigners();
  console.log("Triển khai với địa chỉ:", deployer.address);

  // Kiểm tra balance
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Balance:", hre.ethers.formatEther(balance), "ETH");

  // Triển khai contract
  const BaseToken = await hre.ethers.getContractFactory("BaseToken");
  const baseToken = await BaseToken.deploy(tokenName, tokenSymbol, initialSupply);

  await baseToken.waitForDeployment();

  const contractAddress = await baseToken.getAddress();
  console.log("Contract đã được triển khai tại:", contractAddress);
  console.log("Tên token:", tokenName);
  console.log("Symbol:", tokenSymbol);
  console.log("Initial Supply:", hre.ethers.formatEther(initialSupply), tokenSymbol);

  // Chờ một chút để đảm bảo transaction được xác nhận
  console.log("\nĐang chờ xác nhận...");
  await baseToken.deploymentTransaction()?.wait(5);

  console.log("\n✅ Triển khai thành công!");
  console.log("\nĐể verify contract trên Basescan, chạy lệnh:");
  console.log(
    `npx hardhat verify --network base ${contractAddress} "${tokenName}" "${tokenSymbol}" ${initialSupply}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

