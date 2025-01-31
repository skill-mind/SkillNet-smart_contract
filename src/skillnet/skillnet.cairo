#[starknet::contract]
/// @title Events Management Contract
/// @notice A contract for creating and managing events with registration and attendance tracking
/// @dev Implements Ownable and Upgradeable components from OpenZeppelin
pub mod SkillNet {
    use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry},
    };
    use core::starknet::contract_address;
    use contract::base::types::{CourseDetails, CertificationDetails, ResourceType, studentsDetails};
    use contract::interfaces::ISkillNet::ISkillNet;
    use contract::interfaces::IErc20::{IERC20DispatcherTrait, IERC20Dispatcher};
    use contract::interfaces::IErc721::{IERC721Dispatcher, IERC721DispatcherTrait};

    /// @notice Contract storage structure
    #[storage]
    struct Storage {
        courses_count: u256,
        certifications_count: u256,
        course_details: Map<u256, CourseDetails>, // map(course_id, CourseDetails)
        course_instructors: Map<u256, ContractAddress>, // map(course_id, CourseInstructor)
        certification_details: Map<
            u256, CertificationDetails,
        >, // map(certification_id, CertificationDetails)
        token_address: ContractAddress,
        NFT_contract_address: ContractAddress,
        certification_enrolled_students: Map<
            (u256, ContractAddress), studentsDetails,
        > // (certificate_id, student) -> bool
    }

    /// @notice Events emitted by the contract
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        NewCourseCreated: NewCourseCreated,
        EnrolledForCourse: EnrolledForCourse,
        NewCertificationCreated: NewCertificationCreated,
        EnrolledForCertification: EnrolledForCertification,
        CertificateMinted: CertificateMinted,
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

    #[derive(Drop, starknet::Event)]
    pub struct CertificateMinted {
        pub student: ContractAddress,
        pub certificate_id: u256,
        pub minted_nft_id: u256,
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
    fn constructor(ref self: ContractState, token_address: ContractAddress ,NFT_contract_address: ContractAddress,) {
        self.courses_count.write(0);
        self.certifications_count.write(0);
        self.token_address.write(token_address);
        self.NFT_contract_address.write(NFT_contract_address);
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

        fn enroll_for_course(ref self: ContractState, course_id: u256) {
            // Get course details and verify course exists
            let course = self.course_details.read(course_id);
            assert(course.course_id == course_id, 'Course does not exist');

            // Get student and instructor addresses
            let student = get_caller_address();
            let instructor = course.instructor;

            let token = self.token_address.read();
            let erc20 = IERC20Dispatcher { contract_address: token };

            // Check user's balance
            let user_balance = erc20.balance_of(student).into();
            assert(user_balance >= course.enroll_fee, 'Insufficient balance');

            // Execute payment transfer
            erc20.transfer_from(student, instructor, course.enroll_fee.try_into().unwrap());

            // Update total enrolled count
            let new_total = course.total_enrolled + 1;
            let course_name = course.name.clone();
            let updated_course = CourseDetails { total_enrolled: new_total, ..course };
            self.course_details.write(course_id, updated_course);

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

        fn enroll_for_certification(ref self: ContractState, certificate_id: u256) {
            // Get certification details and verify certification exists
            let student = get_caller_address();
            let certification = self.certification_details.read(certificate_id);
            let mut studentData = self
            .certification_enrolled_students
            .read((certificate_id, student));
            assert(
                certification.certification_id == certificate_id, 'Certification does not exist',
            );

            // Get student and institution addresses         
            let institution = certification.institution;

            let token = self.token_address.read();
            let erc20 = IERC20Dispatcher { contract_address: token };

            // Check user's balance
            let user_balance = erc20.balance_of(student).into();
            assert(user_balance >= certification.enroll_fee, 'Insufficient balance');

            // Execute payment transfer
            erc20.transfer_from(student, institution, certification.enroll_fee.try_into().unwrap());

            // Update total enrolled count
            let new_total = certification.total_enrolled + 1;
            let certification_name = certification.name.clone();
            let updated_certification = CertificationDetails {
                total_enrolled: new_total, ..certification,
            };

            studentData.certification_id = certificate_id;
            studentData.enrolled = true;
            self.certification_details.write(certificate_id, updated_certification);
            self.certification_enrolled_students.write((certificate_id, student), studentData);

            // Emit enrollment event
            self
                .emit(
                    EnrolledForCertification {
                        certification_id: certificate_id,
                        certification: certification_name,
                        student_address: student,
                    },
                );
        }

        fn mint_exam_certificate(ref self: ContractState, certificate_id: u256) -> u256 {
            let student = get_caller_address();

            // Check if the student has already minted this certificate
            let mut studentData = self
                .certification_enrolled_students
                .read((certificate_id, student));
            assert(studentData.certification_id == certificate_id, 'Invalid certificate id');
            assert(studentData.enrolled, 'student_not_enrolled');
            // assert(studentData.passed_exam, 'student_not_passed_exam');
            assert(studentData.minted_NFT == 0, 'Certificate_already_minted');

            // Mint certification NFT
            let nft_address = self.NFT_contract_address.read();
            let erc721 = IERC721Dispatcher { contract_address: nft_address };
            let minted_nft_id = erc721.mint_nft(student);

            // Mark certificate as minted if successful
            studentData.minted_NFT = minted_nft_id;
            self.certification_enrolled_students.write((certificate_id, student), studentData);

            self.emit(CertificateMinted { student, certificate_id, minted_nft_id });
            minted_nft_id
        }

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
