use core::result::ResultTrait;
use core::traits::{TryInto};
use starknet::{ContractAddress};
use snforge_std::{
    declare, spy_events, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, EventSpyAssertionsTrait,
};
use contract::interfaces::ISkillNet::{ISkillNetDispatcher, ISkillNetDispatcherTrait};
use contract::skillnet::skillnet::SkillNet;

const BARRETO: felt252 = 'BARRETO';
const WESCOT: felt252 = 'WESCOT';

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> ContractAddress {
    // deploy skillnet
    let skillnet_class_hash = declare("SkillNet").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![];
    let (skillnet_contract_address, _) = skillnet_class_hash
        .deploy(@events_constructor_calldata)
        .unwrap();

    skillnet_contract_address
}

#[test]
fn test_create_course() {
    let skillnet_contract_address = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };

    start_cheat_caller_address(skillnet_contract_address, BARRETO.try_into().unwrap());
    let course_id = skillnet_dispatcher.create_course("BaseCamp 11", 0);
    assert(course_id == 1, 'Course not created');
    stop_cheat_caller_address(skillnet_contract_address);
}

#[test]
fn test_create_should_emit_event_on_success() {
    let skillnet_contract_address = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };

    let instructor: ContractAddress = BARRETO.try_into().unwrap();
    start_cheat_caller_address(skillnet_contract_address, instructor);
    let mut spy = spy_events();
    skillnet_dispatcher.create_course("BaseCamp 11", 0);
    let expected_event = SkillNet::Event::NewCourseCreated(
        SkillNet::NewCourseCreated { course_id: 100, name: "BaseCamp 11", instructor: instructor },
    );
    spy.assert_emitted(@array![(skillnet_contract_address, expected_event)]);
    stop_cheat_caller_address(skillnet_contract_address);
}
