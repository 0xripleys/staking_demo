#[test_only]
module staking_demo::staking_demo_tests {
    use sui::address;
    use sui_system::staking_pool::StakedSui;
    use sui::test_scenario::{Self, Scenario};
    use sui_system::sui_system::SuiSystemState;
    use sui::coin::{Self};
    use sui::sui::SUI;
    use sui_system::governance_test_utils::{
        advance_epoch_with_reward_amounts,
        create_validators_with_stakes,
        create_sui_system_state_for_testing,
    };

    /* Constants */
    const MIST_PER_SUI: u64 = 1_000_000_000;

    fun setup_sui_system(scenario: &mut Scenario, stakes: vector<u64>) {
        let validators = create_validators_with_stakes(stakes, scenario.ctx());
        create_sui_system_state_for_testing(validators, 0, 0, scenario.ctx());

        advance_epoch_with_reward_amounts(0, 0, scenario);
    }

     public struct TEST has drop {}

     #[test]
     fun test_create_staked_sui_withdraw_immediately() {
        let mut scenario = test_scenario::begin(@0x0);

        setup_sui_system(&mut scenario, vector[100]);
        scenario.next_tx(@0x0);

        assert!(scenario.ctx().epoch() == 1, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let staked_sui = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        assert!(staked_sui.amount() == 100 * MIST_PER_SUI, 0);
        assert!(staked_sui.stake_activation_epoch() == 2, 0);

        // prior to SIP-33, this line would abort!
        let sui = system_state.request_withdraw_stake_non_entry(staked_sui, scenario.ctx());
        assert!(sui.value() == 100 * MIST_PER_SUI, 0); // no rewards earned yet.


        sui::test_utils::destroy(sui);
        test_scenario::return_shared(system_state);
        scenario.end();
     }

     #[test]
     fun test_create_staked_sui_withdraw_after_one_epoch() {
        let mut scenario = test_scenario::begin(@0x0);

        setup_sui_system(&mut scenario, vector[100]);
        scenario.next_tx(@0x0);

        assert!(scenario.ctx().epoch() == 1, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let staked_sui = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        assert!(staked_sui.amount() == 100 * MIST_PER_SUI, 0);
        assert!(staked_sui.stake_activation_epoch() == 2, 0);

        test_scenario::return_shared(system_state);
        advance_epoch_with_reward_amounts(0, 100, &mut scenario);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let sui = system_state.request_withdraw_stake_non_entry(staked_sui, scenario.ctx());
        assert!(sui.value() == 100 * MIST_PER_SUI, 0); // no rewards earned yet still!.

        sui::test_utils::destroy(sui);
        test_scenario::return_shared(system_state);
        scenario.end();
     }

     #[test]
     fun test_create_staked_sui_withdraw_after_two_epochs() {
        let mut scenario = test_scenario::begin(@0x0);

        setup_sui_system(&mut scenario, vector[100]);
        scenario.next_tx(@0x0);

        assert!(scenario.ctx().epoch() == 1, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let staked_sui = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        assert!(staked_sui.amount() == 100 * MIST_PER_SUI, 0);
        assert!(staked_sui.stake_activation_epoch() == 2, 0);

        test_scenario::return_shared(system_state);
        advance_epoch_with_reward_amounts(0, 100, &mut scenario); // stake is now active
        assert!(scenario.ctx().epoch() == 2, 0);

        advance_epoch_with_reward_amounts(0, 300, &mut scenario);
        assert!(scenario.ctx().epoch() == 3, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let sui = system_state.request_withdraw_stake_non_entry(staked_sui, scenario.ctx());
        assert!(sui.value() == 200 * MIST_PER_SUI, 0); // finally i have earned some rewards.

        sui::test_utils::destroy(sui);
        test_scenario::return_shared(system_state);
        scenario.end();
     }

     #[test]
     fun test_join_staked_sui_same_epochs() {
        let mut scenario = test_scenario::begin(@0x0);

        setup_sui_system(&mut scenario, vector[100]);
        scenario.next_tx(@0x0);

        assert!(scenario.ctx().epoch() == 1, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let mut staked_sui_1 = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        let staked_sui_2 = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        staked_sui_1.join(staked_sui_2);
        assert!(staked_sui_1.amount() == 200 * MIST_PER_SUI, 0);

        sui::test_utils::destroy(staked_sui_1);
        test_scenario::return_shared(system_state);
        scenario.end();
     }

     #[test]
     #[expected_failure(abort_code=12, location=sui_system::staking_pool)]
     fun test_join_staked_sui_diff_epochs() {
        let mut scenario = test_scenario::begin(@0x0);

        setup_sui_system(&mut scenario, vector[100]);
        scenario.next_tx(@0x0);

        assert!(scenario.ctx().epoch() == 1, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let mut staked_sui_1 = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        test_scenario::return_shared(system_state);
        advance_epoch_with_reward_amounts(0, 100, &mut scenario); // stake is now active

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let staked_sui_2 = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        staked_sui_1.join(staked_sui_2);
        assert!(staked_sui_1.amount() == 200 * MIST_PER_SUI, 0);

        sui::test_utils::destroy(staked_sui_1);
        test_scenario::return_shared(system_state);
        scenario.end();
     }

     #[test]
     fun test_join_fungible_staked_sui() {
        let mut scenario = test_scenario::begin(@0x0);

        setup_sui_system(&mut scenario, vector[100]);
        scenario.next_tx(@0x0);

        assert!(scenario.ctx().epoch() == 1, 0);

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let staked_sui_1 = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        test_scenario::return_shared(system_state);
        advance_epoch_with_reward_amounts(0, 0, &mut scenario); // stake_1 is now active

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let staked_sui_2 = system_state.request_add_stake_non_entry(
            coin::mint_for_testing(100 * MIST_PER_SUI, scenario.ctx()), 
            address::from_u256(0 as u256), // validator_index
            scenario.ctx()
        );

        test_scenario::return_shared(system_state);
        advance_epoch_with_reward_amounts(0, 0, &mut scenario); // stake_2 is now active

        let mut system_state = scenario.take_shared<SuiSystemState>();
        let mut fungible_stake_1 = system_state.convert_to_fungible_staked_sui(staked_sui_1, scenario.ctx());
        let fungible_stake_2 = system_state.convert_to_fungible_staked_sui(staked_sui_2, scenario.ctx());

        fungible_stake_1.join(fungible_stake_2);
        assert!(fungible_stake_1.value() == 200 * MIST_PER_SUI, 0);

        sui::test_utils::destroy(fungible_stake_1);
        test_scenario::return_shared(system_state);
        scenario.end();
     }
}
