use crypto::digest::Digest;
use crypto::sha2::Sha256;
use std::thread;
use std::time::Instant;

pub fn add1_to_bytes(input: & mut [u8; 132]) {
    let mut i : usize = 1;
    loop{
        if input[input.len() - i] != 255 {
            input[input.len() - i] += 1;
            break;
        }
        else {
            input[input.len() - i] = 0;
            i += 1;
        }
    }
}

pub fn main() {
    let threads: Vec<_> = (0..8)
        .map(|i: u8| {
            thread::spawn(move || {
                let now = Instant::now();
                let mut hasher = Sha256::new();
                let mut output = [0u8; 32];

                // these bytes correspond to the abi encoding of the selector, the magic hash, and a signature of less than 32 bytes
                let mut input: [u8; 132] = [22, 38, 186, 126, //selector - 8 bytes
                25, 187, 52, 226, 147, 187, 169, 107, 240, 202, 238, 165, 76, 221, 61, 45, 173, 127, 223, 68, 203, 234, 133, 81, 115, 250, 132, 83, 79, 207, 181, 40, //hash - 32 bytes
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, //see abi.encode
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,     //see abi.encode
                0, //signature.length
                255/(i+1), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; //actual signature data, depends on i to starts our threads at different places
                
                let mut index : usize = 0;

                loop{    
                    add1_to_bytes(&mut input);

                    hasher.input(&input);
                    hasher.result(& mut output);
                    hasher.reset();

                    if output[0] == 22 && output[1] == 38 && output[2] == 186 {
                        let elapsed_time = now.elapsed();
                        index += 1;
                        println!("Thread {} found {} times three correct starting bytes - {} seconds elapsed.", i, index, elapsed_time.as_secs());
                        if output[3] == 126 {
                            println!("{}", "FOUND 4 BYTES");
                            println!("{:?}", input);
                            break;
                        }
                    }
                }
            })
        })
        .collect();

    for handle in threads {
        handle.join().unwrap();
    }

}
