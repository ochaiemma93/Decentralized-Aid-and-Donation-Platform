import { describe, expect, it } from "vitest";
import { Cl } from '@stacks/transactions';

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("allowlist contract tests", () => {
  it("init-owner can only be called once", () => {
    const { result: result1 } = simnet.callPublicFn("allowlist", "init-owner", [Cl.principal(wallet1)], deployer);
    expect(result1).toBeOk(Cl.bool(true));
    
    const { result: result2 } = simnet.callPublicFn("allowlist", "init-owner", [Cl.principal(wallet1)], deployer);
    expect(result2).toBeErr(Cl.uint(1003));
  });

  it("add and remove require owner authorization", () => {
    const { result: result1 } = simnet.callPublicFn("allowlist", "init-owner", [Cl.principal(wallet1)], deployer);
    expect(result1).toBeOk(Cl.bool(true));
    
    const { result: result2 } = simnet.callPublicFn("allowlist", "add", [Cl.principal(wallet2)], wallet2);
    expect(result2).toBeErr(Cl.uint(1000));
  });

  it("add on existing member fails with u1001", () => {
    const { result: result1 } = simnet.callPublicFn("allowlist", "init-owner", [Cl.principal(wallet1)], deployer);
    expect(result1).toBeOk(Cl.bool(true));
    
    const { result: result2 } = simnet.callPublicFn("allowlist", "add", [Cl.principal(wallet2)], wallet1);
    expect(result2).toBeOk(Cl.bool(true));
    
    const { result: result3 } = simnet.callPublicFn("allowlist", "add", [Cl.principal(wallet2)], wallet1);
    expect(result3).toBeErr(Cl.uint(1001));
  });

  it("remove on non-member fails with u1002", () => {
    const { result: result1 } = simnet.callPublicFn("allowlist", "init-owner", [Cl.principal(wallet1)], deployer);
    expect(result1).toBeOk(Cl.bool(true));
    
    const { result: result2 } = simnet.callPublicFn("allowlist", "remove", [Cl.principal(wallet2)], wallet1);
    expect(result2).toBeErr(Cl.uint(1002));
  });

  it("is-allowed reflects membership accurately", () => {
    const { result: result1 } = simnet.callPublicFn("allowlist", "init-owner", [Cl.principal(wallet1)], deployer);
    expect(result1).toBeOk(Cl.bool(true));
    
    const { result: result2 } = simnet.callPublicFn("allowlist", "add", [Cl.principal(wallet2)], wallet1);
    expect(result2).toBeOk(Cl.bool(true));
    
    const { result: check1 } = simnet.callReadOnlyFn("allowlist", "is-allowed", [Cl.principal(wallet2)], deployer);
    expect(check1).toBeBool(true);
    
    const { result: result3 } = simnet.callPublicFn("allowlist", "remove", [Cl.principal(wallet2)], wallet1);
    expect(result3).toBeOk(Cl.bool(true));
    
    const { result: check2 } = simnet.callReadOnlyFn("allowlist", "is-allowed", [Cl.principal(wallet2)], deployer);
    expect(check2).toBeBool(false);
  });
});
