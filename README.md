# TeamWork - Employee Attendance Management System

![TeamWork Logo](assets/images/logo.png)

## Overview

TeamWork is a comprehensive Flutter-based employee attendance management system designed to streamline attendance tracking, team management, and organizational operations. The application provides a secure and efficient way for organizations to manage employee attendance, track work hours, and maintain team structures.

## Features

### Organization Management
- **Organization Codes**: Secure generation and verification of unique organization codes
- **Admin Dashboard**: Comprehensive tools for organization management
- **Team Structure**: Create and manage teams within your organization

### User Authentication
- **Firebase Authentication**: Secure login and registration
- **Offline Authentication**: Continue using the app even without internet connection
- **Biometric Authentication**: Fingerprint and face recognition for quick and secure login
- **Role-based Access**: Different permissions for admins and regular users
- **Organization Connection**: Connect users to organizations via codes
- **Enhanced Security**: Password hashing and secure credential storage

### Attendance Management
- **Biometric Check-in/out**: Secure attendance verification
- **Location Tracking**: Verify attendance location
- **Attendance History**: View and export attendance records
- **Work Hours Calculation**: Automatic calculation of work hours

### Team Management
- **Team Creation**: Create and manage teams
- **Member Assignment**: Assign employees to teams
- **Team Analytics**: View team attendance statistics

### Reporting
- **Attendance Reports**: Generate and export attendance reports
- **Analytics Dashboard**: Visual representation of attendance data
- **PDF Export**: Export reports in PDF format

## Technical Architecture

### Frontend
- **Flutter**: Cross-platform UI framework
- **Provider**: State management
- **Flutter Bloc**: Advanced state management for complex features

### Backend
- **Firebase**: Authentication, real-time database, and cloud functions
- **SQLite**: Local database for offline functionality
- **Shared Preferences**: Local storage for user settings

### Security
- **Biometric Authentication**: Secure check-in/out process and login
- **Firebase Authentication**: Secure user authentication
- **Offline Security**: Encrypted local storage of credentials
- **Secure Token Management**: Automatic token refresh and session management

## Enhanced Authentication System

TeamWork features a robust authentication system designed to work seamlessly in both online and offline environments:

### Offline Authentication
- Continue using the app even without internet connection
- Securely cached credentials with automatic expiration
- Seamless transition between online and offline modes

### Biometric Integration
- Fast and secure login using fingerprint or face recognition
- Securely stored credentials using device-level encryption
- Support for multiple biometric types across different devices

### Security Features
- Password hashing using SHA-256
- Secure credential storage with Flutter Secure Storage
- Token refresh mechanism to maintain session security
- Comprehensive error handling with user-friendly messages
- **Encrypted Storage**: Secure storage of sensitive information

## Project Structure

```
attendance_team/
├── lib/
│   ├── main.dart                # Application entry point
│   ├── database_helper.dart     # SQLite database operations
│   ├── screens/                 # UI screens
│   │   ├── auth/                # Authentication screens
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home_screen.dart     # Main dashboard
│   │   ├── organization_screen.dart  # Organization management
│   │   └── attendance_history_screen.dart  # Attendance records
│   └── widgets/                 # Reusable UI components
│       └── connection_check_wrapper.dart  # Organization connection check
├── assets/                      # Application assets
│   ├── images/                  # Images and graphics
│   └── icons/                   # Custom icons
└── pubspec.yaml                 # Dependencies and configuration
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Firebase account and project setup
- Android Studio or VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/attendance_team.git
   cd attendance_team
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Add Android and iOS apps to your Firebase project
   - Download and add the configuration files (google-services.json for Android, GoogleService-Info.plist for iOS)
   - Enable Authentication, Firestore, and other required services

4. **Run the application**
   ```bash
   flutter run
   ```

## Usage

### Admin Setup
1. Register as an admin
2. Generate an organization code
3. Share the code with team members
4. Create teams and manage organization settings

### Employee Usage
1. Register as a regular user
2. Enter the organization code provided by admin
3. Use the app to check in and out
4. View attendance history and team information

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For any inquiries or support, please contact:
- Email: support@teamwork-app.com
- GitHub Issues: [https://github.com/yourusername/attendance_team/issues](https://github.com/yourusername/attendance_team/issues)


## What technologies are used for this project?

This project is built with:

- Vite
- TypeScript
- React
- shadcn-ui
- Tailwind CSS

## How can I deploy this project?

Simply open [Lovable](https://lovable.dev/projects/4f6946d1-72f4-432f-8f73-801934d8b5ba) and click on Share -> Publish.

## Can I connect a custom domain to my Lovable project?

Yes, you can!

To connect a domain, navigate to Project > Settings > Domains and click Connect Domain.

Read more here: [Setting up a custom domain](https://docs.lovable.dev/tips-tricks/custom-domain#step-by-step-guide)
