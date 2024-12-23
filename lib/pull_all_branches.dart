import 'dart:io';
import 'package:args/args.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('all', 
      abbr: 'a', 
      negatable: false, 
      help: 'Advance all branches without asking');

  final argResults = parser.parse(arguments);
  final advanceAll = argResults['all'] as bool;

  try {
    // Get all local branches
    final branchResult = await Process.run('git', ['branch']);
    if (branchResult.exitCode != 0) {
      throw 'Failed to get local branches';
    }

    final branches = branchResult.stdout.toString()
        .split('\n')
        .where((branch) => branch.isNotEmpty)
        .map((branch) => branch.trim().replaceAll('* ', ''))
        .map((branch) => branch.trim().replaceAll('+ ', ''))  // worktree branches
        .where((branch) => branch.isNotEmpty)
        .toList();

    for (final branch in branches) {
      // Check if branch is behind remote
      final statusResult = await Process.run(
          'git', ['rev-list', '--left-right', '--count', '$branch...origin/$branch']);
      
      if (statusResult.exitCode != 0) {
        print('Warning: Could not check status for branch $branch');
        continue;
      }

      final counts = statusResult.stdout.toString().trim().split('\t');
      if (counts.length != 2) continue;

      final behindCount = int.tryParse(counts[1]) ?? 0;
      
      if (behindCount > 0) {
        print('Branch $branch is behind by $behindCount commits');
        
        bool shouldAdvance = advanceAll;
        if (!advanceAll) {
          stdout.write('Would you like to advance this branch? (y/n): ');
          final response = stdin.readLineSync()?.toLowerCase() ?? 'n';
          shouldAdvance = response == 'y' || response == 'yes';
        }

        if (shouldAdvance) {
          print('Advancing branch $branch...');
          final fetchResult = await Process.run(
              'git', ['fetch', 'origin', '$branch:$branch']);
          
          if (fetchResult.exitCode == 0) {
            print('Successfully advanced $branch');
          } else {
            print('Failed to advance $branch: ${fetchResult.stderr}');
          }
        }
      }
    }
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
