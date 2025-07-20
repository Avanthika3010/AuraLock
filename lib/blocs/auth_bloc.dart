import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Events
abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  LoginRequested({required this.email, required this.password});
}

class LogoutRequested extends AuthEvent {}

class AuthStateChanged extends AuthEvent {
  final User? user;

  AuthStateChanged(this.user);
}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final User user;

  AuthSuccess(this.user);
}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure(this.message);
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthBloc() : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthStateChanged>(_onAuthStateChanged);

    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      add(AuthStateChanged(user));
    });
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      if (userCredential.user != null) {
        emit(AuthSuccess(userCredential.user!));
      } else {
        emit(AuthFailure('Login failed: No user returned'));
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email address.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      emit(AuthFailure(message));
    } catch (e) {
      emit(AuthFailure('Login failed: $e'));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _auth.signOut();
      emit(AuthInitial());
    } catch (e) {
      emit(AuthFailure('Logout failed: $e'));
    }
  }

  void _onAuthStateChanged(AuthStateChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      emit(AuthSuccess(event.user!));
    } else {
      emit(AuthInitial());
    }
  }

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user email
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
}

/// Example usage in a widget:
/// 
/// ```dart
/// class LoginScreen extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return BlocProvider(
///       create: (context) => AuthBloc(),
///       child: BlocListener<AuthBloc, AuthState>(
///         listener: (context, state) {
///           if (state is AuthSuccess) {
///             Navigator.pushReplacementNamed(context, '/home');
///           } else if (state is AuthFailure) {
///             ScaffoldMessenger.of(context).showSnackBar(
///               SnackBar(content: Text(state.message)),
///             );
///           }
///         },
///         child: Scaffold(
///           body: BlocBuilder<AuthBloc, AuthState>(
///             builder: (context, state) {
///               if (state is AuthLoading) {
///                 return Center(child: CircularProgressIndicator());
///               }
///               
///               return LoginForm();
///             },
///           ),
///         ),
///       ),
///     );
///   }
/// }
/// 
/// class LoginForm extends StatelessWidget {
///   final _emailController = TextEditingController();
///   final _passwordController = TextEditingController();
/// 
///   @override
///   Widget build(BuildContext context) {
///     return Form(
///       child: Column(
///         children: [
///           TextFormField(
///             controller: _emailController,
///             decoration: InputDecoration(labelText: 'Email'),
///           ),
///           TextFormField(
///             controller: _passwordController,
///             decoration: InputDecoration(labelText: 'Password'),
///             obscureText: true,
///           ),
///           ElevatedButton(
///             onPressed: () {
///               context.read<AuthBloc>().add(
///                 LoginRequested(
///                   email: _emailController.text,
///                   password: _passwordController.text,
///                 ),
///               );
///             },
///             child: Text('Login'),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ``` 