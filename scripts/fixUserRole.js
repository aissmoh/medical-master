// Script to fix existing user: set isPatient=true and remove the 'role' field
import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log("Connected to MongoDB");

  // Fix the specific user
  const result = await mongoose.connection.db.collection("users").updateOne(
    { email: "roufaida2003@gmail.com" },
    {
      $set: { isPatient: true },
      $unset: { role: "" }
    }
  );

  console.log(`Matched: ${result.matchedCount}, Modified: ${result.modifiedCount}`);

  // Verify
  const user = await mongoose.connection.db.collection("users").findOne({ email: "roufaida2003@gmail.com" });
  console.log("\n--- Updated User ---");
  console.log(`Name: ${user.name}`);
  console.log(`Email: ${user.email}`);
  console.log(`isPatient: ${user.isPatient}`);
  console.log(`role field exists: ${"role" in user}`);

  // Also remove 'role' field from ALL users in the collection
  const bulkResult = await mongoose.connection.db.collection("users").updateMany(
    { role: { $exists: true } },
    { $unset: { role: "" } }
  );
  console.log(`\nRemoved 'role' field from ${bulkResult.modifiedCount} other user(s).`);

  await mongoose.disconnect();
  console.log("\nDone ✅");
}

main().catch(console.error);
