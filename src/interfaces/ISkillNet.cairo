use starknet::ContractAddress;

#[starknet::interface]
pub trait ISkillNet<TContractState> {
    // Courses
    fn create_course(ref self: TContractState, name: ByteArray, fee: u256) -> u256;
    fn enroll_for_course(ref self: TContractState, course_id: u256);
    fn mint_course_certificate(ref self: TContractState, course_id: u256) -> u256;
    fn verify_course_credential(self: @TContractState, course_id: u256, student: ContractAddress);

    // Examinations/Certifications
    fn create_certification(ref self: TContractState, name: ByteArray, fee: u256) -> u256;
    fn enroll_for_certification(ref self: TContractState, certificate_id: u256);
    fn mint_exam_certificate(ref self: TContractState, certificate_id: u256);
    fn verify_exam_certificate(
        self: @TContractState, certificate_id: u256, student: ContractAddress,
    );
}
