#[starknet::contract]
/// @title Events Management Contract
/// @notice A contract for creating and managing events with registration and attendance tracking
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod SkillNet {
    use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry},
    };
    use contract::base::types::{CourseDetails, CertificationDetails, ResourceType};
    use contract::interfaces::ISkillNet::ISkillNet;
    /// @notice Contract storage structure
    #[storage]
    struct Storage {
        courses_count: u256,
        certifications_count: u256,
        course_details: Map<u256, CourseDetails>, // map(course_id, CourseDetails)
        course_instructors: Map<u256, ContractAddress>, // map(course_id, CourseInstructor)
        certification_details: Map<
            u256, CertificationDetails,
        > // map(certification_id, CertificationDetails)
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NewCourseCreated: NewCourseCreated,
        EnrolledForCourse: EnrolledForCourse,
        NewCertificationCreated: NewCertificationCreated,
        EnrolledForCertification: EnrolledForCertification,
    }

    /// @notice Event emitted when a new course is created
    #[derive(Drop, starknet::Event)]
    pub struct NewCourseCreated {
        pub name: ByteArray,
        pub course_id: u256,
        pub instructor: ContractAddress,
    }

    /// @notice Event emitted when a user enrolls for a course
    #[derive(Drop, starknet::Event)]
    pub struct EnrolledForCourse {
        pub course_id: u256,
        pub course_name: ByteArray,
        pub student_address: ContractAddress,
    }

    /// @notice Event emitted when a new certification is created
    #[derive(Drop, starknet::Event)]
    pub struct NewCertificationCreated {
        pub name: ByteArray,
        pub certification_id: u256,
        pub institution: ContractAddress,
    }

    /// @notice Event emitted when a user enrolls for a course
    #[derive(Drop, starknet::Event)]
    pub struct EnrolledForCertification {
        pub certification_id: u256,
        pub certification: ByteArray,
        pub student_address: ContractAddress,
    }

    /// @notice Initializes the Events contract
    /// @dev Sets the initial event count to 0
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.courses_count.write(0);
        self.certifications_count.write(0);
    }

    #[abi(embed_v0)]
    impl SkillNetImpl of ISkillNet<ContractState> {
        /// @notice Creates a new course
        /// @param name Name of the course
        /// @param fee Enrollment fee
        /// @return course_id The ID of the newly created event
        fn create_course(ref self: ContractState, name: ByteArray, fee: u256) -> u256 {
            let instructor = get_caller_address();
            let course_name = name.clone();
            let course_id = self._create_course(course_name, fee, instructor);

            self
                .emit(
                    NewCourseCreated { name: name, course_id: course_id, instructor: instructor },
                );
            course_id
        }

        fn enroll_for_course(ref self: ContractState, course_id: u256, fee: u256) {
            // Get course details and verify course exists
            let course = self.course_details.read(course_id);
            assert(course.course_id == course_id, 'Course does not exist');

            // Verify correct fee is provided
            assert(course.enroll_fee == fee, 'Incorrect fee amount');

            // Get student address
            let student = get_caller_address();

            // Update total enrolled count
            let new_total = course.total_enrolled + 1;
            let course_name = course.name.clone();
            let updated_course = CourseDetails { total_enrolled: new_total, ..course };
            self.course_details.write(course_id, updated_course);

            // Emit enrollment event
            self.emit(EnrolledForCourse { course_id, course_name, student_address: student });
        }

        fn mint_course_certificate(ref self: ContractState, course_id: u256) {}

        fn verify_course_credential(
            self: @ContractState, course_id: u256, student: ContractAddress,
        ) {}

        /// @notice Creates a new Certification
        /// @param name Name of Certification
        /// @param fee Certification fee
        /// @return sertification_id The ID of the newly created event
        fn create_certification(ref self: ContractState, name: ByteArray, fee: u256) -> u256 {
            let institution = get_caller_address();
            let cert_name = name.clone();
            let certification_id = self._create_certification(name, fee, institution);

            self
                .emit(
                    NewCertificationCreated {
                        name: cert_name,
                        certification_id: certification_id,
                        institution: institution,
                    },
                );
            certification_id
        }

        fn enroll_for_certification(ref self: ContractState, certificate_id: u256, fee: u256) {}

        fn mint_exam_certificate(ref self: ContractState, certificate_id: u256) {}

        fn verify_exam_certificate(
            self: @ContractState, certificate_id: u256, student: ContractAddress,
        ) {}
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// @notice create new course
        /// @param course_name: Name of the course.
        /// @param course_fee: Course enrollment fee.
        /// @param instructor: Course instructor.
        /// @return ID of the created course.
        fn _create_course(
            ref self: ContractState,
            course_name: ByteArray,
            course_fee: u256,
            instructor: ContractAddress,
        ) -> u256 {
            let course_id = self.courses_count.read() + 1;
            self.courses_count.write(course_id);

            let course_type = match course_fee > 0 {
                true => ResourceType::Paid,
                false => ResourceType::Free,
            };

            let course_details = CourseDetails {
                course_id: course_id,
                name: course_name,
                instructor: instructor,
                total_enrolled: 0,
                course_type: course_type,
                enroll_fee: course_fee,
            };

            self.course_details.write(course_id, course_details);
            self.course_instructors.write(course_id, instructor);

            course_id
        }

        /// @notice create certification
        /// @param name: Name of certification
        /// @param course_fee: Certification enrollment fee.
        /// @param institution: Institution hosting the certification.
        /// @return ID of the created certification.
        fn _create_certification(
            ref self: ContractState, name: ByteArray, fee: u256, institution: ContractAddress,
        ) -> u256 {
            let certification_id = self.certifications_count.read() + 1;
            self.certifications_count.write(certification_id);

            let certificate_type = match fee > 0 {
                true => ResourceType::Paid,
                false => ResourceType::Free,
            };

            let certification_details = CertificationDetails {
                certification_id,
                name,
                institution,
                total_enrolled: 0,
                certificate_type,
                enroll_fee: fee,
            };

            self.certification_details.write(certification_id, certification_details);

            certification_id
        }
    }
}
