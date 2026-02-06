import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'package:dabbler/core/fp/result.dart';

class VenuesConsumer extends StatelessWidget {
  const VenuesConsumer({super.key});

  static const _demoVenueId = '00000000-0000-0000-0000-000000000000';
  static const _noFilters = (city: null, district: null, q: null);

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final venuesAsync = ref.watch(activeVenuesProvider(_noFilters));
        final spacesAsync = ref.watch(
          spacesByVenueStreamProvider(_demoVenueId),
        );

        return venuesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (venuesResult) => venuesResult.match(
            (failure) => Center(child: Text(failure.message)),
            (venues) {
              if (venues.isEmpty) {
                return const Center(child: Text('No venues available.'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView.separated(
                      itemCount: venues.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final venue = venues[index];
                        return ListTile(
                          title: Text(venue.name),
                          subtitle: venue.city != null
                              ? Text(venue.city!)
                              : null,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: spacesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) =>
                          Center(child: Text(error.toString())),
                      data: (spacesResult) => spacesResult.match(
                        (failure) => Center(
                          child: Text('Spaces error: ${failure.message}'),
                        ),
                        (spaces) {
                          if (spaces.isEmpty) {
                            return const Center(
                              child: Text('No spaces for demo venue.'),
                            );
                          }
                          return ListView.separated(
                            itemCount: spaces.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final space = spaces[index];
                              return ListTile(
                                title: Text(space.name),
                                // sportKey removed from VenueSpace; omit subtitle if not available
                                subtitle: null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
