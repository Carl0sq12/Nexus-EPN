import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_strings.dart';
import '../constants/app_colors.dart';
import '../providers/session_data_provider.dart';
import '../providers/appwrite_provider.dart';

// Real pages
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/pages/onboarding_profile_page.dart';
import '../../features/auth/presentation/pages/onboarding_vehicle_page.dart';
import '../../features/auth/presentation/pages/onboarding_contacts_page.dart';
import '../../features/auth/presentation/pages/vehicle_pending_page.dart';
import '../../features/onboarding/domain/entities/onboarding_status.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/vehicles/presentation/pages/vehicle_page.dart';
import '../../features/vehicles/presentation/pages/edit_vehicle_page.dart';
import '../../features/trips/presentation/pages/trips_list_page.dart';
import '../../features/trips/presentation/pages/destination_search_page.dart';
import '../../features/trips/presentation/pages/my_trips_page.dart';
import '../../features/trips/presentation/pages/create_trip_page.dart';
import '../../features/trips/presentation/pages/trip_detail_page.dart';
import '../../features/trips/presentation/pages/trip_navigation_page.dart';
import '../../features/trips/presentation/pages/trip_report_page.dart';
import '../../features/requests/presentation/pages/request_management_page.dart';
import '../../features/requests/presentation/pages/passenger_trip_request_page.dart';
import '../../features/requests/presentation/pages/requests_inbox_page.dart';
import '../../features/requests/presentation/pages/request_detail_page.dart';
import '../../features/requests/domain/entities/trip_request.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/sos/presentation/pages/sos_page.dart';
import '../../features/sos/presentation/widgets/global_sos_fab.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notifications/presentation/pages/security_settings_page.dart';
import '../../features/trips/presentation/pages/passenger_history_page.dart';

/// Exposes the application's GoRouter configured with redirect rules based on
/// the Appwrite auth state.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: AppStrings.routeSplash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUserId = ref.read(currentUserIdProvider);
      final onboardingAsync = ref.read(onboardingStatusProvider);
      final isLoadingSession = authState.isLoading && currentUserId == null;
      final isAuthenticated =
          authState.asData?.value != null || currentUserId != null;
      final onAuthRoute = state.matchedLocation.startsWith('/auth');
      final onOnboardingRoute = state.matchedLocation.startsWith('/onboarding');
      final onSplash = state.matchedLocation == AppStrings.routeSplash;
      final onHome =
          state.matchedLocation == AppStrings.routeHome ||
          state.matchedLocation.startsWith('/home');

      if (isLoadingSession) {
        return onSplash ? null : AppStrings.routeSplash;
      }
      if (!isAuthenticated && !onAuthRoute) return AppStrings.routeLogin;
      if (!isAuthenticated) return null;

      // Keep user on splash while onboarding loads; do NOT bounce away from
      // an already-resolved home/onboarding screen on every reload.
      if (onboardingAsync.isLoading) {
        if (onSplash || onOnboardingRoute) return null;
        // Stay put if we already have a previous successful status cached
        // via previous data; otherwise go splash with visible loader.
        final previous = onboardingAsync.asData?.value;
        if (previous != null && previous.canEnterHome && onHome) {
          return null;
        }
        return AppStrings.routeSplash;
      }

      if (onboardingAsync.hasError) {
        // Stay on splash with retry UI; splash handles error display.
        return onSplash ? null : AppStrings.routeSplash;
      }

      final onboardingStatus = onboardingAsync.asData?.value;
      if (onboardingStatus == null) {
        return onSplash || onOnboardingRoute ? null : AppStrings.routeSplash;
      }

      final requiredRoute = _routeForOnboardingStep(onboardingStatus.step);
      final mustCompleteOnboarding =
          onboardingStatus.step != OnboardingStep.home;

      if (onSplash) return requiredRoute;

      if (mustCompleteOnboarding) {
        return state.matchedLocation == requiredRoute ? null : requiredRoute;
      }

      if (onAuthRoute || onOnboardingRoute) return AppStrings.routeHome;
      final matched = state.matchedLocation;
      final driverOnlyRoute =
          matched == AppStrings.routeTripsNew ||
          matched == AppStrings.routeMyTrips ||
          // Trip request management: /trips/:id/requests — NOT /requests inbox.
          (matched.startsWith('${AppStrings.routeTrips}/') &&
              matched.endsWith('/requests')) ||
          matched.endsWith('/navigation');
      if (driverOnlyRoute &&
          (onboardingStatus.role != AppStrings.roleDriver ||
              !onboardingStatus.hasVehicle ||
              !onboardingStatus.isVehicleApproved)) {
        return AppStrings.routeTrips;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppStrings.routeSplash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppStrings.routeLogin,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppStrings.routeRegister,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppStrings.routeForgot,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppStrings.routeVerifyEmail,
        builder: (context, state) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: AppStrings.routeOnboardingProfile,
        builder: (context, state) => const OnboardingProfilePage(),
      ),
      GoRoute(
        path: AppStrings.routeOnboardingVehicle,
        builder: (context, state) => const OnboardingVehiclePage(),
      ),
      GoRoute(
        path: AppStrings.routeOnboardingVehiclePending,
        builder: (context, state) => const VehiclePendingPage(),
      ),
      GoRoute(
        path: AppStrings.routeOnboardingContacts,
        builder: (context, state) => const OnboardingContactsPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppStrings.routeHome,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppStrings.routeNotifications,
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: AppStrings.routeRequests,
            builder: (context, state) => const RequestsInboxPage(),
            routes: [
              GoRoute(
                path: ':requestId',
                builder: (context, state) => RequestDetailPage(
                  requestId: state.pathParameters['requestId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppStrings.routeSecurity,
            builder: (context, state) => const SecuritySettingsPage(),
          ),
          GoRoute(
            path: AppStrings.routeTrips,
            builder: (context, state) =>
                TripsListPage(destinationQuery: state.uri.queryParameters['q']),
            routes: [
              GoRoute(
                path: 'search',
                builder: (context, state) => const DestinationSearchPage(),
              ),
              GoRoute(
                path: 'new',
                builder: (context, state) => CreateTripPage(
                  editTripId: state.uri.queryParameters['edit'],
                ),
              ),
              GoRoute(
                path: 'my',
                builder: (context, state) => const MyTripsPage(),
              ),
              GoRoute(
                path: 'history',
                builder: (context, state) => const PassengerHistoryPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    TripDetailPage(tripId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'requests',
                    builder: (context, state) => RequestManagementPage(
                      tripId: state.pathParameters['id']!,
                    ),
                  ),
                  GoRoute(
                    path: 'request',
                    builder: (context, state) => PassengerTripRequestPage(
                      tripId: state.pathParameters['id']!,
                      initialStop: state.extra is TripRequestStop
                          ? state.extra as TripRequestStop
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'navigation',
                    builder: (context, state) =>
                        TripNavigationPage(tripId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'report',
                    builder: (context, state) =>
                        TripReportPage(tripId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppStrings.routeChat,
            builder: (context, state) => const ChatListPage(),
          ),
          GoRoute(
            path: '/chat/:tripId',
            builder: (context, state) =>
                ChatPage(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: AppStrings.routeMap,
            builder: (context, state) => const MapPage(),
          ),
          GoRoute(
            path: AppStrings.routeProfile,
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfilePage(),
              ),
            ],
          ),
          GoRoute(
            path: AppStrings.routeVehicle,
            builder: (context, state) => const VehiclePage(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditVehiclePage(),
              ),
            ],
          ),
          GoRoute(
            path: AppStrings.routeSos,
            builder: (context, state) => const SosPage(),
          ),
        ],
      ),
    ],
  );
});

final routerRefreshProvider = Provider<Listenable>((ref) {
  final notifier = _RouterRefreshNotifier();

  ref.listen<AsyncValue<AppAuthSession?>>(authStateProvider, (previous, next) {
    final previousUserId = previous?.asData?.value?.userId;
    final nextUserId = next.asData?.value?.userId;
    if (previousUserId != nextUserId || next.hasError) {
      // Single invalidation path — do not also bump sessionDataVersion here
      // (login already bumps it). Avoids double onboarding reload races.
      ref.invalidate(onboardingStatusProvider);
    }
    notifier.notify();
  }, fireImmediately: true);

  ref.listen(onboardingStatusProvider, (previous, next) => notifier.notify());
  ref.listen(sessionDataVersionProvider, (previous, next) => notifier.notify());
  ref.onDispose(notifier.dispose);

  return notifier;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Shell widget with bottom navigation bar for the main app sections.
class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    // Passengers use the header solicitudes icon; bottom nav has no Solicitudes tab.
    final navRoutes = <String>[
      AppStrings.routeHome,
      AppStrings.routeTrips,
      AppStrings.routeChat,
      AppStrings.routeProfile,
    ];

    var currentIndex = navRoutes.indexWhere((r) => location.startsWith(r));
    if (currentIndex < 0) currentIndex = 0;

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        label: 'Inicio',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.directions_car_outlined),
        label: 'Viajes',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat_bubble_outline),
        label: 'Mensajes',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: 'Perfil',
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          if (location != AppStrings.routeSos) const GlobalSosFab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, AppColors.background],
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => context.go(navRoutes[index]),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: items,
        ),
      ),
    );
  }
}

String _routeForOnboardingStep(OnboardingStep step) {
  switch (step) {
    case OnboardingStep.unauthenticated:
      return AppStrings.routeLogin;
    case OnboardingStep.verifyEmail:
      return AppStrings.routeVerifyEmail;
    case OnboardingStep.completeProfile:
      return AppStrings.routeOnboardingProfile;
    case OnboardingStep.registerVehicle:
      return AppStrings.routeOnboardingVehicle;
    case OnboardingStep.vehiclePending:
      return AppStrings.routeOnboardingVehiclePending;
    case OnboardingStep.registerContacts:
      return AppStrings.routeOnboardingContacts;
    case OnboardingStep.home:
      return AppStrings.routeHome;
  }
}
