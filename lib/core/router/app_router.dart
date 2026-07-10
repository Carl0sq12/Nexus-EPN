import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_strings.dart';
import '../constants/app_colors.dart';
import '../providers/session_data_provider.dart';
import '../providers/supabase_provider.dart';

// Real pages
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/pages/onboarding_profile_page.dart';
import '../../features/auth/presentation/pages/onboarding_vehicle_page.dart';
import '../../features/auth/presentation/pages/onboarding_contacts_page.dart';
import '../../features/onboarding/domain/entities/onboarding_status.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/vehicles/presentation/pages/vehicle_page.dart';
import '../../features/vehicles/presentation/pages/edit_vehicle_page.dart';
import '../../features/trips/presentation/pages/trips_list_page.dart';
import '../../features/trips/presentation/pages/my_trips_page.dart';
import '../../features/trips/presentation/pages/create_trip_page.dart';
import '../../features/trips/presentation/pages/trip_detail_page.dart';
import '../../features/trips/presentation/pages/trip_navigation_page.dart';
import '../../features/requests/presentation/pages/request_management_page.dart';
import '../../features/requests/presentation/pages/passenger_trip_request_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/chat_list_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/sos/presentation/pages/sos_page.dart';

/// Exposes the application's GoRouter configured with redirect rules based on
/// the Supabase auth state.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshProvider);

  return GoRouter(
    initialLocation: AppStrings.routeSplash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentSession = ref
          .read(supabaseClientProvider)
          .auth
          .currentSession;
      final onboardingAsync = ref.read(onboardingStatusProvider);
      final isLoadingSession = authState.isLoading && currentSession == null;
      final isAuthenticated =
          authState.asData?.value.session != null || currentSession != null;
      final onAuthRoute = state.matchedLocation.startsWith('/auth');
      final onOnboardingRoute = state.matchedLocation.startsWith('/onboarding');
      final onSplash = state.matchedLocation == AppStrings.routeSplash;

      if (isLoadingSession) {
        return onSplash ? null : AppStrings.routeSplash;
      }
      if (!isAuthenticated && !onAuthRoute) return AppStrings.routeLogin;
      if (!isAuthenticated) return null;

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
      final driverOnlyRoute =
          state.matchedLocation == AppStrings.routeTripsNew ||
          state.matchedLocation == AppStrings.routeMyTrips ||
          state.matchedLocation.endsWith('/requests');
      if (driverOnlyRoute &&
          (onboardingStatus.role != AppStrings.roleDriver ||
              !onboardingStatus.hasVehicle)) {
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
            path: AppStrings.routeTrips,
            builder: (context, state) => const TripsListPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateTripPage(),
              ),
              GoRoute(
                path: 'my',
                builder: (context, state) => const MyTripsPage(),
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
                    ),
                  ),
                  GoRoute(
                    path: 'navigation',
                    builder: (context, state) =>
                        TripNavigationPage(tripId: state.pathParameters['id']!),
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

  ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) {
    final previousUserId = previous?.asData?.value.session?.user.id;
    final nextUserId = next.asData?.value.session?.user.id;
    if (previousUserId != nextUserId || next.hasError) {
      ref.invalidate(onboardingStatusProvider);
      ref.read(sessionDataVersionProvider.notifier).state++;
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
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  static const _navRoutes = [
    AppStrings.routeHome,
    AppStrings.routeTrips,
    AppStrings.routeSos,
    AppStrings.routeChat,
    AppStrings.routeProfile,
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _navRoutes.indexWhere((r) => location.startsWith(r));

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, AppColors.background],
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex < 0 ? 0 : currentIndex,
          onTap: (index) => context.go(_navRoutes[index]),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              label: 'Viajes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emergency_outlined),
              label: 'Auxilio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Mensajes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
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
    case OnboardingStep.registerContacts:
      return AppStrings.routeOnboardingContacts;
    case OnboardingStep.home:
      return AppStrings.routeHome;
  }
}
