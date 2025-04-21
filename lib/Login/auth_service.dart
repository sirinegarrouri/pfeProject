import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("❌ Sign-up error: ${e.message}");
      return null;
    }
  }
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("❌ Sign-in error: ${e.message}");
      return null;
    }
  }
  Future<void> signOut() async {
    await _auth.signOut();
  }
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print("📩 Password reset email sent!");
    } on FirebaseAuthException catch (e) {
      print("❌ Password reset error: ${e.message}");
    }
  }
}
