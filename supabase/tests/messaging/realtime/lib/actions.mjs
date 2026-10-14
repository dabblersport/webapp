// KAN-545: the ONE wrapper every roster change and every block goes through. A call is refused BEFORE any request
// is sent unless it targets the fixture game or the other test account:
//   rpc_leave_game / rpc_join_game   B only, p_actor_type 'player', p_game_id = the fixture game
//   rpc_remove_player                A only, p_game_id = the fixture game, p_profile_id = B's profile
//   rpc_block_user / rpc_unblock_user  B only, p_peer = A's user id
// Any other function, game id or user id throws GuardError("foreign-target"); the message names no id.

import { GuardError } from "./guards.mjs";

export function makeGuardedActions({ fixtureGameId, uidA, profileIdB }) {
  const refuse = () => {
    throw new GuardError("foreign-target", "refused: the target is outside the fixture game and the two test accounts");
  };
  return function act(actor, client, name, params = {}) {
    const fixture = params.p_game_id === fixtureGameId;
    switch (name) {
      case "rpc_leave_game":
      case "rpc_join_game":
        if (actor !== "B" || !fixture || params.p_actor_type !== "player") refuse();
        break;
      case "rpc_remove_player":
        if (actor !== "A" || !fixture || params.p_profile_id !== profileIdB) refuse();
        break;
      case "rpc_block_user":
      case "rpc_unblock_user":
        if (actor !== "B" || params.p_peer !== uidA) refuse();
        break;
      default:
        refuse();
    }
    return client.rpc(name, params);
  };
}
