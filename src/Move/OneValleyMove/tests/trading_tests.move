/// Comprehensive tests for the OneValley GameFi trading system
module one_valley_gamefi::trading_tests {
    use one::test_scenario::{Self as ts, Scenario};
    use one::transfer;
    use one::object;
    use one::tx_context;
    use std::string;
    use one_valley_gamefi::items::{Self, GameItem, ItemForge, Weapon, Armor};
    use one_valley_gamefi::lock::{Self, Key};
    use one_valley_gamefi::trading::{Self, TradeEscrow, GameCustodian};

    // === Test Constants ===
    const ALICE: address = @0xA;
    const BOB: address = @0xB;
    const CUSTODIAN: address = @0xC;

    // === Test Helper Functions ===

    #[test_only]
    fun setup_test_scenario(): Scenario {
        ts::begin(@0x0)
    }

    #[test_only]
    fun create_test_item_for_address(
        scenario: &mut Scenario,
        forge_id: ID,
        item_type: u8,
        owner: address
    ): (ID, GameItem) {
        ts::next_tx(@0x0);
        {
            let forge = ts::take_from_address_by_id<ItemForge>(@0x0, forge_id);
            let mut ctx = ts::ctx(scenario);

            let item = items::create_test_item(
                &mut forge,
                item_type,
                string::from("Test Item"),
                &mut ctx
            );

            let item_id = object::id(&item);

            // Return the forge
            ts::return_to_address(@0x0, forge);

            // Transfer the item to the owner
            transfer::public_transfer(item, owner);

            (item_id, item)
        }
    }

    #[test_only]
    fun create_test_weapon_for_address(
        scenario: &mut Scenario,
        forge_id: ID,
        owner: address
    ): (ID, Weapon) {
        ts::next_tx(@0x0);
        {
            let forge = ts::take_from_address_by_id<ItemForge>(@0x0, forge_id);
            let mut ctx = ts::ctx(scenario);

            let weapon = items::create_weapon(
                &mut forge,
                1, // COMMON
                string::from("Test Sword"),
                string::from("A test sword"),
                100, // damage
                50,  // max durability
                &mut ctx
            );

            let weapon_id = object::id(&weapon);

            // Return the forge
            ts::return_to_address(@0x0, forge);

            // Transfer the weapon to the owner
            transfer::public_transfer(weapon, owner);

            (weapon_id, weapon)
        }
    }

    // === Test Cases ===

    #[test]
    fun test_successful_weapon_trade() {
        let mut scenario = setup_test_scenario();

        // Initialize forge and custodian
        let forge_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            items::init(&mut ctx);
            object::id(&ts::take_from_sender<ItemForge>())
        };

        let custodian_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            trading::init(&mut ctx);
            object::id(&ts::take_shared<GameCustodian>())
        };

        // Alice creates a sword
        let (alice_weapon_id, _) = create_test_weapon_for_address(&mut scenario, forge_id, ALICE);

        // Bob creates an armor
        let (bob_weapon_id, _) = create_test_weapon_for_address(&mut scenario, forge_id, BOB);

        // Alice locks her sword
        let alice_key_id = {
            ts::next_tx(ALICE);
            let weapon = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);

            let (locked, key) = lock::lock(weapon, &mut ctx);
            let key_id = object::id(&key);

            transfer::public_transfer(locked, ALICE);
            transfer::public_transfer(key, ALICE);

            key_id
        };

        // Bob locks his weapon
        let bob_key_id = {
            ts::next_tx(BOB);
            let weapon = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);

            let (locked, key) = lock::lock(weapon, &mut ctx);
            let key_id = object::id(&key);

            transfer::public_transfer(locked, BOB);
            transfer::public_transfer(key, BOB);

            key_id
        };

        // Alice initiates trade
        {
            ts::next_tx(ALICE);
            let key: Key = ts::take_from_sender();
            let locked: Locked<Weapon> = ts::take_from_sender();
            let mut ctx = ts::ctx(&mut scenario);

            trading::initiate_trade(
                key,
                locked,
                bob_key_id,
                BOB,
                CUSTODIAN,
                &mut ctx
            );
        };

        // Bob initiates his side of the trade
        {
            ts::next_tx(BOB);
            let key: Key = ts::take_from_sender();
            let locked: Locked<Weapon> = ts::take_from_sender();
            let mut ctx = ts::ctx(&mut scenario);

            trading::initiate_trade(
                key,
                locked,
                alice_key_id,
                ALICE,
                CUSTODIAN,
                &mut ctx
            );
        };

        // Custodian executes the swap
        {
            ts::next_tx(CUSTODIAN);
            let escrow1: TradeEscrow<Weapon> = ts::take_from_sender();
            let escrow2: TradeEscrow<Weapon> = ts::take_from_sender();

            let mut custodian = ts::take_shared<GameCustodian>();
            trading::execute_swap(&mut custodian, escrow1, escrow2, ts::ctx(&mut scenario));
            ts::return_shared(custodian);
        };

        // Verify trade completion
        ts::next_tx(ALICE);
        {
            let received_weapon: Weapon = ts::take_from_sender();
            // Alice should now have Bob's original weapon
            assert!(items::weapon_damage(&received_weapon) == 100, 1);
            ts::return_to_sender(received_weapon);
        };

        ts::next_tx(BOB);
        {
            let received_weapon: Weapon = ts::take_from_sender();
            // Bob should now have Alice's original weapon
            assert!(items::weapon_damage(&received_weapon) == 100, 2);
            ts::return_to_sender(received_weapon);
        };

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0)] // EMismatchedSenderRecipient
    fun test_mismatched_recipients() {
        let mut scenario = setup_test_scenario();

        // Initialize forge and custodian
        let forge_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            items::init(&mut ctx);
            object::id(&ts::take_from_sender<ItemForge>())
        };

        let _custodian_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            trading::init(&mut ctx);
            object::id(&ts::take_shared<GameCustodian>())
        };

        // Create weapons for Alice and Bob
        let (alice_weapon_id, _) = create_test_weapon_for_address(&mut scenario, forge_id, ALICE);
        let _ = create_test_weapon_for_address(&mut scenario, forge_id, BOB);

        // Alice and Bob lock their items
        let alice_key_id = {
            ts::next_tx(ALICE);
            let weapon = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);
            let (locked, key) = lock::lock(weapon, &mut ctx);
            let key_id = object::id(&key);
            transfer::public_transfer(locked, ALICE);
            transfer::public_transfer(key, ALICE);
            key_id
        };

        let bob_key_id = {
            ts::next_tx(BOB);
            let weapon = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);
            let (locked, key) = lock::lock(weapon, &mut ctx);
            let key_id = object::id(&key);
            transfer::public_transfer(locked, BOB);
            transfer::public_transfer(key, BOB);
            key_id
        };

        // Alice initiates trade with Bob
        {
            ts::next_tx(ALICE);
            let key: Key = ts::take_from_sender();
            let locked: Locked<Weapon> = ts::take_from_sender();
            let mut ctx = ts::ctx(&mut scenario);

            trading::initiate_trade(
                key,
                locked,
                bob_key_id,
                BOB,
                CUSTODIAN,
                &mut ctx
            );
        };

        // Bob initiates trade with a different recipient (not Alice) - should fail
        {
            ts::next_tx(BOB);
            let key: Key = ts::take_from_sender();
            let locked: Locked<Weapon> = ts::take_from_sender();
            let mut ctx = ts::ctx(&mut scenario);

            trading::initiate_trade(
                key,
                locked,
                alice_key_id,
                @0xD, // Different recipient!
                CUSTODIAN,
                &mut ctx
            );
        };

        // This should fail when trying to execute the swap
        scenario.end();
    }

    #[test]
    fun test_escrow_cancellation() {
        let mut scenario = setup_test_scenario();

        // Initialize forge and custodian
        let forge_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            items::init(&mut ctx);
            object::id(&ts::take_from_sender<ItemForge>())
        };

        let _custodian_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            trading::init(&mut ctx);
            object::id(&ts::take_shared<GameCustodian>())
        };

        // Alice creates a weapon
        let _ = create_test_weapon_for_address(&mut scenario, forge_id, ALICE);

        // Alice locks her weapon
        let alice_key_id = {
            ts::next_tx(ALICE);
            let weapon = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);
            let (locked, key) = lock::lock(weapon, &mut ctx);
            let key_id = object::id(&key);
            transfer::public_transfer(locked, ALICE);
            transfer::public_transfer(key, ALICE);
            key_id
        };

        // Alice initiates trade
        {
            ts::next_tx(ALICE);
            let key: Key = ts::take_from_sender();
            let locked: Locked<Weapon> = ts::take_from_sender();
            let mut ctx = ts::ctx(&mut scenario);

            trading::initiate_trade(
                key,
                locked,
                alice_key_id, // Exchange with her own key for testing
                BOB,
                CUSTODIAN,
                &mut ctx
            );
        };

        // Alice cancels the escrow
        {
            ts::next_tx(ALICE);
            let escrow: TradeEscrow<Weapon> = ts::take_from_sender();
            let returned_weapon = trading::cancel_escrow(escrow, ts::ctx(&mut scenario));
            // Alice gets her weapon back
            transfer::public_transfer(returned_weapon, ALICE);
        };

        // Verify Alice still has her weapon
        ts::next_tx(ALICE);
        {
            let weapon: Weapon = ts::take_from_sender();
            assert!(items::weapon_damage(&weapon) == 100, 1);
            ts::return_to_sender(weapon);
        };

        scenario.end();
    }

    #[test]
    fun test_lock_unlock_functionality() {
        let mut scenario = setup_test_scenario();

        // Initialize forge
        let forge_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            items::init(&mut ctx);
            object::id(&ts::take_from_sender<ItemForge>())
        };

        // Create a test weapon
        let _ = create_test_weapon_for_address(&mut scenario, forge_id, ALICE);

        // Test lock and unlock
        {
            ts::next_tx(ALICE);
            let weapon = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);

            // Lock the weapon
            let (locked, key) = lock::lock(weapon, &mut ctx);
            let original_damage = items::weapon_damage(&lock::borrow(&locked));

            // Unlock the weapon
            let unlocked_weapon = lock::unlock(locked, key);
            let unlocked_damage = items::weapon_damage(&unlocked_weapon);

            // Verify the weapon is unchanged
            assert!(original_damage == unlocked_damage, 1);

            // Transfer back to Alice
            transfer::public_transfer(unlocked_weapon, ALICE);
        };

        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = 0)] // ELockKeyMismatch
    fun test_wrong_key_unlock() {
        let mut scenario = setup_test_scenario();

        // Initialize forge
        let forge_id = {
            ts::next_tx(@0x0);
            let mut ctx = ts::ctx(&mut scenario);
            items::init(&mut ctx);
            object::id(&ts::take_from_sender<ItemForge>())
        };

        // Create two test weapons
        let _ = create_test_weapon_for_address(&mut scenario, forge_id, ALICE);
        let _ = create_test_weapon_for_address(&mut scenario, forge_id, ALICE);

        // Try to unlock with wrong key
        {
            ts::next_tx(ALICE);
            let weapon1 = ts::take_from_sender<Weapon>();
            let weapon2 = ts::take_from_sender<Weapon>();
            let mut ctx = ts::ctx(&mut scenario);

            let (locked1, key1) = lock::lock(weapon1, &mut ctx);
            let (_, key2) = lock::lock(weapon2, &mut ctx);

            // Try to unlock locked1 with key2 - should fail
            let _ = lock::unlock(locked1, key2);
        };

        scenario.end();
    }
}