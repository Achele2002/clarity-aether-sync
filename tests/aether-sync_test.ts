import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure client authorization works correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const client = accounts.get("wallet_1")!;
    
    let block = chain.mineBlock([
      Tx.contractCall("aether-sync", "authorize-client", 
        [types.principal(client.address)], deployer.address
      )
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');
    
    let isAuthorized = chain.callReadOnlyFn(
      "aether-sync",
      "is-client-authorized",
      [types.principal(client.address)],
      deployer.address
    );
    assertEquals(isAuthorized.result, 'true');
  }
});

Clarinet.test({
  name: "Test sync state recording with enhanced validation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const client = accounts.get("wallet_1")!;
    
    // First authorize client
    chain.mineBlock([
      Tx.contractCall("aether-sync", "authorize-client",
        [types.principal(client.address)], deployer.address
      )
    ]);
    
    // Test valid sync
    let block = chain.mineBlock([
      Tx.contractCall("aether-sync", "record-sync",
        [
          types.uint(1),
          types.buff(Buffer.from("0".repeat(64), "hex")),
          types.uint(0)
        ],
        client.address
      )
    ]);
    assertEquals(block.receipts[0].result, '(ok true)');

    // Test invalid version gap
    block = chain.mineBlock([
      Tx.contractCall("aether-sync", "record-sync",
        [
          types.uint(12), // Too big gap
          types.buff(Buffer.from("0".repeat(64), "hex")),
          types.uint(1)
        ],
        client.address
      )
    ]);
    assertEquals(block.receipts[0].result.includes('err'), true);

    // Test invalid hash
    block = chain.mineBlock([
      Tx.contractCall("aether-sync", "record-sync",
        [
          types.uint(2),
          types.buff(Buffer.from("0".repeat(62), "hex")), // Invalid hash length
          types.uint(1)
        ],
        client.address
      )
    ]);
    assertEquals(block.receipts[0].result.includes('err'), true);
  }
});
