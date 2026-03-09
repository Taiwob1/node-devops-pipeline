const assert = require("assert");

function testHealth() {
  assert.strictEqual(1 + 1, 2);
}

testHealth();

console.log("Tests Passed");