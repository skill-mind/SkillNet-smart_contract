use core::result::ResultTrait;
use core::traits::{TryInto};
use starknet::{ContractAddress};
use snforge_std::{
    declare, spy_events, start_cheat_caller_address, stop_cheat_caller_address, ContractClassTrait,
    DeclareResultTrait, EventSpyAssertionsTrait,
};
use contract::interfaces::ISkillNet::{ISkillNetDispatcher, ISkillNetDispatcherTrait};
use contract::interfaces::IErc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use contract::interfaces::IErc721::{IERC721Dispatcher, IERC721DispatcherTrait};


use contract::skillnet::skillnet::SkillNet;
use contract::skillnet::ERC20::erc20;
use contract::skillnet::ERC721::erc721;

const BARRETO: felt252 = 'BARRETO';
const WESCOT: felt252 = 'WESCOT';
const ADMIN: felt252 = 'ADMIN';

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    WESCOT.try_into().unwrap()
}

// *************************************************************************
//                              SETUP
// *************************************************************************
fn __setup__() -> (ContractAddress, ContractAddress, ContractAddress) {
    let erc20_class_hash = declare("erc20").unwrap().contract_class();

    let erc721_contract_address = __deploy_ERC721__();

    let mut erc20_constructor_calldata = array![];
    USER().serialize(ref erc20_constructor_calldata); // recipient
    'Test Token'.serialize(ref erc20_constructor_calldata); // name
    8.serialize(ref erc20_constructor_calldata); // decimals
    1000000.serialize(ref erc20_constructor_calldata); // initial supply
    'TT'.serialize(ref erc20_constructor_calldata); // symbol

    let (erc20_contract_address, _) = erc20_class_hash.deploy(@erc20_constructor_calldata).unwrap();

    // Deploy SkillNet with token address and NFT address
    let skillnet_class_hash = declare("SkillNet").unwrap().contract_class();

    let mut skillnet_constructor_calldata = array![];
    erc20_contract_address.serialize(ref skillnet_constructor_calldata);
    erc721_contract_address.serialize(ref skillnet_constructor_calldata);

    let (skillnet_contract_address, _) = skillnet_class_hash
        .deploy(@skillnet_constructor_calldata)
        .unwrap();

    (skillnet_contract_address, erc20_contract_address, erc721_contract_address)
}


fn __deploy_ERC721__() -> ContractAddress {
    let nft_class_hash = declare("erc721").unwrap().contract_class();

    let mut events_constructor_calldata: Array<felt252> = array![ADMIN];
    let (nft_contract_address, _) = nft_class_hash.deploy(@events_constructor_calldata).unwrap();

    return (nft_contract_address);
}


#[test]
fn test_create_course() {
    let (skillnet_contract_address, _, _) = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };

    start_cheat_caller_address(skillnet_contract_address, BARRETO.try_into().unwrap());
    let course_id = skillnet_dispatcher.create_course("BaseCamp 11", 0);
    assert(course_id == 1, 'Course not created');
    stop_cheat_caller_address(skillnet_contract_address);
}

#[test]
fn test_create_should_emit_event_on_success() {
    let (skillnet_contract_address, _, _) = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };

    let instructor: ContractAddress = BARRETO.try_into().unwrap();
    start_cheat_caller_address(skillnet_contract_address, instructor);
    let mut spy = spy_events();
    skillnet_dispatcher.create_course("BaseCamp 11", 0);
    let expected_event = SkillNet::Event::NewCourseCreated(
        SkillNet::NewCourseCreated { course_id: 1, name: "BaseCamp 11", instructor: instructor },
    );
    spy.assert_emitted(@array![(skillnet_contract_address, expected_event)]);
    stop_cheat_caller_address(skillnet_contract_address);
}

#[test]
fn test_create_certification_success() {
    let (skillnet_contract_address, _, _) = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };
    let caller: ContractAddress = BARRETO.try_into().unwrap();

    start_cheat_caller_address(skillnet_contract_address, caller);
    let mut spy = spy_events();
    let certification_id = skillnet_dispatcher.create_certification("BaseCamp 11", 0);
    assert(certification_id == 1, 'Certification not created');
    let expected_event = SkillNet::Event::NewCertificationCreated(
        SkillNet::NewCertificationCreated {
            certification_id: 1, name: "BaseCamp 11", institution: caller,
        },
    );
    spy.assert_emitted(@array![(skillnet_contract_address, expected_event)]);
    stop_cheat_caller_address(skillnet_contract_address);
}

#[test]
fn test_enroll_for_course() {
    let (skillnet_contract_address, erc20_contract_address, _) = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_contract_address };

    // Create a course first
    let instructor: ContractAddress = BARRETO.try_into().unwrap();
    let student: ContractAddress = WESCOT.try_into().unwrap();

    // Create course with fee
    start_cheat_caller_address(skillnet_contract_address, instructor);
    let course_id = skillnet_dispatcher.create_course("BaseCamp 11", 100);
    stop_cheat_caller_address(skillnet_contract_address);

    // Approve token spending before enrollment
    start_cheat_caller_address(skillnet_contract_address, student);
    erc20_dispatcher.approve(skillnet_contract_address, 100);

    // Enroll in course
    let mut spy = spy_events();
    skillnet_dispatcher.enroll_for_course(course_id);

    // Verify enrollment event
    let expected_event = SkillNet::Event::EnrolledForCourse(
        SkillNet::EnrolledForCourse {
            course_id, course_name: "BaseCamp 11", student_address: student,
        },
    );
    spy.assert_emitted(@array![(skillnet_contract_address, expected_event)]);
    stop_cheat_caller_address(skillnet_contract_address);
}

#[test]
fn test_mint_exam_certificate() {
    let (skillnet_contract_address, _, erc721_contract_address) = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };

    let instructor: ContractAddress = BARRETO.try_into().unwrap();
    let student: ContractAddress = WESCOT.try_into().unwrap();

    // Create a course first
    start_cheat_caller_address(skillnet_contract_address, instructor);
    let certificate_id = skillnet_dispatcher.create_certification("BaseCamp 11", 0);
    stop_cheat_caller_address(skillnet_contract_address);

    // Enroll student in course
    start_cheat_caller_address(skillnet_contract_address, student);
    skillnet_dispatcher.enroll_for_certification(certificate_id);

    // Mint certificate after exam completion

    let mut spy = spy_events();
    let nft_id = skillnet_dispatcher.mint_exam_certificate(certificate_id);
    assert(nft_id == 1, 'Certificate not minted');

    // Verify minting event
    let expected_event = SkillNet::Event::CertificateMinted(
        SkillNet::CertificateMinted {
            student: student, certificate_id: certificate_id, minted_nft_id: nft_id,

fn test_enroll_for_certification() {
    let (skillnet_contract_address, erc20_contract_address) = __setup__();
    let skillnet_dispatcher = ISkillNetDispatcher { contract_address: skillnet_contract_address };
    let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_contract_address };

    // Define institution and student addresses
    let institution: ContractAddress = BARRETO.try_into().unwrap();
    let student: ContractAddress = WESCOT.try_into().unwrap();

    // Create certification with fee
    start_cheat_caller_address(skillnet_contract_address, institution);
    let certification_id = skillnet_dispatcher.create_certification("Blockchain Developer", 100);
    stop_cheat_caller_address(skillnet_contract_address);

    // Approve token spending before enrollment
    start_cheat_caller_address(skillnet_contract_address, student);
    erc20_dispatcher.approve(skillnet_contract_address, 100);

    // Enroll in certification
    let mut spy = spy_events();
    skillnet_dispatcher.enroll_for_certification(certification_id);

    // Verify enrollment event
    let expected_event = SkillNet::Event::EnrolledForCertification(
        SkillNet::EnrolledForCertification {
            certification_id, certification: "Blockchain Developer", student_address: student,
        },
    );
    spy.assert_emitted(@array![(skillnet_contract_address, expected_event)]);
    stop_cheat_caller_address(skillnet_contract_address);
}
