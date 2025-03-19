module aptos_freelancer_escrow::Freelancer {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_account;
    use aptos_framework::table::{Self, Table};
    
    // Error codes
    const E_NOT_OWNER: u64 = 1;
    const E_INVALID_STATUS: u64 = 2;
    const E_NOT_FREELANCER: u64 = 3;
    const E_NOT_ASSIGNED: u64 = 4;
    const E_NOT_CLIENT: u64 = 5;
    const E_NOT_SUBMITTED: u64 = 6;
    
    struct Job<phantom CoinType> has store {
        id: u64,
        client: address,
        freelancer: address,
        payment_amount: u64,
        status: u8, // 0: Open, 1: Assigned, 2: Submitted, 3: Approved
    }
    
    struct Escrow<phantom CoinType> has key {
        jobs: Table<u64, Job<CoinType>>,
        job_counter: u64,
    }
    
    public entry fun init_escrow<CoinType>(account: &signer) {
        let owner = signer::address_of(account);
        if (!exists<Escrow<CoinType>>(owner)) {
            move_to(account, Escrow<CoinType> { 
                jobs: table::new(), 
                job_counter: 0 
            });
        }
    }
    
    public entry fun create_job<CoinType>(
        client: &signer,
        freelancer: address,
        payment_amount: u64
    ) acquires Escrow {
        let client_addr = signer::address_of(client);
        
        assert!(exists<Escrow<CoinType>>(client_addr), E_NOT_OWNER);
        
        // Transfer payment to module account (would need to be implemented)
        // This simplified version just tracks the amount
        
        let escrow = borrow_global_mut<Escrow<CoinType>>(client_addr);
        let job_id = escrow.job_counter;
        
        let job = Job<CoinType> {
            id: job_id,
            client: client_addr,
            freelancer,
            payment_amount,
            status: 0, // Open
        };
        
        table::add(&mut escrow.jobs, job_id, job);
        escrow.job_counter = job_id + 1;
    }
    
    public entry fun assign_job<CoinType>(
        client: &signer,
        job_id: u64,
        freelancer: address
    ) acquires Escrow {
        let client_addr = signer::address_of(client);
        
        assert!(exists<Escrow<CoinType>>(client_addr), E_NOT_OWNER);
        let escrow = borrow_global_mut<Escrow<CoinType>>(client_addr);
        
        assert!(table::contains(&escrow.jobs, job_id), E_NOT_OWNER);
        let job = table::borrow_mut(&mut escrow.jobs, job_id);
        
        assert!(job.client == client_addr, E_NOT_CLIENT);
        assert!(job.status == 0, E_INVALID_STATUS); // Must be Open
        
        job.freelancer = freelancer;
        job.status = 1; // Assigned
    }
    
    public entry fun submit_work<CoinType>(
        freelancer: &signer,
        client_addr: address,
        job_id: u64
    ) acquires Escrow {
        let freelancer_addr = signer::address_of(freelancer);
        
        assert!(exists<Escrow<CoinType>>(client_addr), E_NOT_OWNER);
        let escrow = borrow_global_mut<Escrow<CoinType>>(client_addr);
        
        assert!(table::contains(&escrow.jobs, job_id), E_NOT_OWNER);
        let job = table::borrow_mut(&mut escrow.jobs, job_id);
        
        assert!(job.freelancer == freelancer_addr, E_NOT_FREELANCER);
        assert!(job.status == 1, E_NOT_ASSIGNED); // Must be Assigned
        
        job.status = 2; // Submitted
    }
    
    public entry fun approve_work<CoinType>(
        client: &signer,
        job_id: u64
    ) acquires Escrow {
        let client_addr = signer::address_of(client);
        
        assert!(exists<Escrow<CoinType>>(client_addr), E_NOT_OWNER);
        let escrow = borrow_global_mut<Escrow<CoinType>>(client_addr);
        
        assert!(table::contains(&escrow.jobs, job_id), E_NOT_OWNER);
        let job = table::borrow_mut(&mut escrow.jobs, job_id);
        
        assert!(job.client == client_addr, E_NOT_CLIENT);
        assert!(job.status == 2, E_NOT_SUBMITTED); // Must be Submitted
        
        // In a real implementation, you would transfer the payment here
        // using coin::transfer() or similar
        
        job.status = 3; // Approved
    }
    
    #[view]
    public fun get_job_status<CoinType>(
        owner: address, 
        job_id: u64
    ): (address, address, u64, u8) acquires Escrow {
        let escrow = borrow_global<Escrow<CoinType>>(owner);
        assert!(table::contains(&escrow.jobs, job_id), E_NOT_OWNER);
        
        let job = table::borrow(&escrow.jobs, job_id);
        (job.client, job.freelancer, job.payment_amount, job.status)
    }
}
