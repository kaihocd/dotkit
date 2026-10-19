import assert from "node:assert/strict";
import { test } from "node:test";
import { allowsAction } from "../../src/deployment/execute/authorization";

test("action authorization covers deployment, network and elevated requirements", () => {
  for (const deployment of [false, true]) {
    for (const network of [false, true]) {
      for (const elevatedPrivileges of [false, true]) {
        for (const needsNetwork of [false, true]) {
          for (const needsElevation of [false, true]) {
            assert.equal(
              allowsAction(
                { network: needsNetwork, elevatedPrivileges: needsElevation },
                { deployment, network, elevatedPrivileges },
              ),
              deployment &&
                (!needsNetwork || network) &&
                (!needsElevation || elevatedPrivileges),
            );
          }
        }
      }
    }
  }
});
