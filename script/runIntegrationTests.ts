import { setupClients } from './utils/client-setup.js';
import { buildContracts } from './utils/deployer.js';
import { ChainConfig, TestFlags } from './utils/types.js';
import { COLORS } from './utils/constants.js';

// Import test modules
import { executeWriteTests } from './tests/write_tests.js';
import { executeReadTests } from './tests/read_tests.js';
import { executeTriggerTests } from './tests/trigger_tests.js';
import { executeUploadTests } from './tests/upload_tests.js';
import { executeSchedulerTests } from './tests/scheduler_tests.js';
import { executeInsufficientFeesTests } from './tests/insufficient_tests.js';
import { executeRevertTests } from './tests/revert_tests.js';

// Global chain configurations
let evmxChain: ChainConfig;
let arbChain: ChainConfig;
let opChain: ChainConfig;

// Initialize chains
function initializeChains(): void {
  const chains = setupClients();
  evmxChain = chains.evmxChain;
  arbChain = chains.arbChain;
  opChain = chains.opChain;
}

// Help function
function showHelp(): void {
  console.log('Usage: npx tsx tests.ts [OPTIONS]');
  console.log('Options:');
  console.log('  -w    Run write tests');
  console.log('  -r    Run read tests');
  console.log('  -t    Run trigger tests');
  console.log('  -u    Run upload tests');
  console.log('  -s    Run scheduler tests');
  console.log('  -i    Run insufficient fees tests');
  console.log('  -v    Run revert tests');
  console.log('  -a    Run all tests');
  console.log('  -?    Show this help message');
  console.log('If no options are provided, this help message is displayed.');
}

// Parse command line flags
function parseFlags(args: string[]): TestFlags {
  return {
    write: args.includes('-w') || args.includes('-a'),
    read: args.includes('-r') || args.includes('-a'),
    trigger: args.includes('-t') || args.includes('-a'),
    upload: args.includes('-u') || args.includes('-a'),
    scheduler: args.includes('-s') || args.includes('-a'),
    insufficient: args.includes('-i') || args.includes('-a'),
    revert: args.includes('-v') || args.includes('-a'),
    all: args.includes('-a')
  };
}

// Main function
async function main(): Promise<void> {
  try {
    await buildContracts();
    initializeChains();

    // Parse command line arguments
    const args = process.argv.slice(2);
    if (args.length === 0 || args.includes('-?')) {
      showHelp();
      return;
    }

    const flags = parseFlags(args);

    // Execute tests based on flags
    if (flags.write) {
      await executeWriteTests(evmxChain, arbChain);
    }

    if (flags.read) {
      await executeReadTests(evmxChain, arbChain);
    }

    if (flags.trigger) {
      await executeTriggerTests(evmxChain, arbChain, opChain);
    }

    if (flags.upload) {
      await executeUploadTests(evmxChain, arbChain);
    }

    if (flags.scheduler) {
      await executeSchedulerTests(evmxChain, arbChain);
    }

    if (flags.insufficient) {
      await executeInsufficientFeesTests(evmxChain, arbChain);
    }

    if (flags.revert) {
      await executeRevertTests(evmxChain, arbChain);
    }

    console.log(`${COLORS.GREEN}All selected tests completed successfully!${COLORS.NC}`);

  } catch (error) {
    console.error(`${COLORS.RED}Error:${COLORS.NC}`, error);
    process.exit(1);
  }
}

// Export the setup for external use
export {
  initializeChains,
  evmxChain,
  arbChain,
  opChain
};

// Run main if this is the main module
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('Unhandled error in main:', error);
    process.exit(1);
  });
}
