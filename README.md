# 🛡️ SafeZone

### GIS-Based Safe Navigation and Crime Risk Mapping Using Kernel Density Estimation

SafeZone is a mobile-based **safe navigation and crime risk mapping application** designed to help users identify areas with potential criminal risk and make safer route decisions.

The application combines **Geographic Information System (GIS)**, **Kernel Density Estimation (KDE)**, and **community-based crime reporting** to transform reported crime incidents into spatial risk information.

> **Research Project / Undergraduate Thesis — Informatics Engineering, Universitas Bakrie**

---

## 📌 Overview

Conventional digital maps primarily focus on finding the shortest or fastest route. However, the shortest route is not necessarily the safest route.

SafeZone addresses this problem by incorporating **crime risk information into navigation**.

The system processes spatial crime incident data and generates a **crime risk distribution map** using Kernel Density Estimation (KDE). The resulting risk information can then be used to identify higher-risk areas and support safer route recommendations.

In addition, SafeZone allows users to report incidents directly from the application. These reports become an additional source of spatial crime data that can contribute to the application's risk analysis.

### Core Concept

```text
User Crime Report
       ↓
Incident Validation
       ↓
Spatial Crime Data
       ↓
Kernel Density Estimation (KDE)
       ↓
Crime Risk Distribution
       ↓
Risk Classification / Crime Risk Index
       ↓
Safe Route Recommendation
```

---

## 🎯 Objectives

SafeZone is developed with the following objectives:

* Visualize the spatial distribution of crime incidents.
* Identify areas with different levels of criminal risk.
* Apply **Kernel Density Estimation (KDE)** to analyze crime concentration.
* Allow users to report crime incidents based on their location.
* Provide users with safety-related information before traveling.
* Support route selection by considering both **distance and crime risk**.
* Develop a mobile-based GIS solution for community safety.

---

## ✨ Key Features

### 🗺️ Crime Risk Map

Displays spatial crime information on an interactive map.

The system can visualize areas according to their estimated crime risk based on processed incident data.

### 📍 Crime Incident Reporting

Users can submit reports of incidents such as:

* Robbery / Begal
* Assault
* Street fights / Tawuran
* Theft
* Traffic accidents
* Other security-related incidents

Each report can contain relevant information such as the incident category, description, location, and timestamp.

### 🔎 Crime Risk Analysis

Reported crime incidents are processed as spatial data.

SafeZone uses **Kernel Density Estimation (KDE)** to estimate the concentration of crime incidents across geographical areas.

Higher crime concentration indicates a potentially higher-risk area.

### 🚨 Community-Based Reporting

Users are not only consumers of safety information but can also contribute data through incident reporting.

This creates a **crowdsourced crime data layer** that can complement existing crime datasets.

### 🧭 Safe Navigation

SafeZone is designed to support route selection based on:

* Travel distance
* Crime risk
* Spatial distribution of incidents

The goal is not simply to find the shortest route, but to identify a route with a **lower estimated criminal risk** while remaining practically usable.

### 🔔 Safety Alerts

Users can receive notifications related to important safety information and reported incidents.

### 🆘 Emergency Contacts

Provides quick access to emergency services such as:

* Police
* Medical services
* Fire department
* SOS

### 👤 User Authentication

Users can register and log in securely using Firebase Authentication.

---

## 🧠 Research Method

### Kernel Density Estimation (KDE)

Kernel Density Estimation is used to estimate the spatial concentration of crime incidents.

Conceptually, each crime incident contributes a probability density around its geographical location.

The KDE result can be represented as:

```text
Crime Incidents
      ●     ●
   ●     ●
        ●       ●
          ↓
        KDE
          ↓
 ┌───────────────────┐
 │ Low Risk          │
 │ Medium Risk       │
 │ High Risk         │
 └───────────────────┘
```

The resulting density surface can then be used as an input for crime risk classification and route analysis.

---

## 🧭 Safe Route Concept

SafeZone extends conventional shortest-path navigation by introducing **crime risk as an additional routing consideration**.

Instead of optimizing only:

```text
Shortest Distance
```

the system is designed to consider:

```text
Distance + Crime Risk
```

This allows the application to prioritize routes that may have a lower estimated crime risk, even when they are not the absolute shortest route.

Possible routing approaches include:

* A* Algorithm
* Dijkstra's Algorithm

The final implementation may select the most appropriate algorithm based on the application's spatial data structure and research requirements.

---

## 🔄 System Workflow

```text
┌───────────────────────┐
│   User Reports Crime  │
└───────────┬───────────┘
            ↓
┌───────────────────────┐
│   Report Validation   │
└───────────┬───────────┘
            ↓
┌───────────────────────┐
│   Spatial Crime Data  │
└───────────┬───────────┘
            ↓
┌───────────────────────┐
│          KDE          │
│ Kernel Density        │
│ Estimation            │
└───────────┬───────────┘
            ↓
┌───────────────────────┐
│   Crime Risk Map      │
└───────────┬───────────┘
            ↓
┌───────────────────────┐
│ Risk-Aware Navigation │
└───────────┬───────────┘
            ↓
┌───────────────────────┐
│ Safer Route Suggestion│
└───────────────────────┘
```

---

## 🏗️ System Architecture

```text
                    ┌─────────────────┐
                    │     Mobile App  │
                    │     Flutter     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ↓              ↓              ↓
        Authentication    Reporting      Mapping
              │              │              │
              └──────────────┼──────────────┘
                             ↓
                    ┌─────────────────┐
                    │    Firebase     │
                    │ Auth / Firestore│
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Crime Spatial   │
                    │ Data Processing │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │      KDE        │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Crime Risk Map  │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Risk-Aware Route│
                    │ Recommendation  │
                    └─────────────────┘
```

---

## 🛠️ Technology Stack

| Technology                    | Purpose                                 |
| ----------------------------- | --------------------------------------- |
| **Flutter**                   | Mobile application development          |
| **Dart**                      | Application programming language        |
| **Firebase Authentication**   | User authentication                     |
| **Cloud Firestore**           | Crime reports and application data      |
| **GIS**                       | Spatial data visualization and analysis |
| **Kernel Density Estimation** | Crime density estimation                |
| **Google Maps / Mapping API** | Map visualization and navigation        |
| **Local Notifications**       | Safety-related notifications            |

---

## 📱 Main Screens

The current application contains several primary screens:

### Home

Provides an overview of security information, emergency categories, and recent reports.

### Map

Displays the surrounding geographical area and crime-related spatial information.

### Report

Allows users to submit a new incident report.

### Alerts

Displays recent reports and safety-related activity.

### Report Detail

Displays detailed information about a reported incident, including verification and community interaction.

### Login / Register

Handles user authentication.

### Settings

Provides profile and application settings.

---

## 📂 Project Structure

```text
lib/
├── app_colors.dart
├── main.dart
├── firebase_options.dart
│
├── models/
│   └── laporan_model.dart
│
├── screens/
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── lapor_screen.dart
│   ├── alerts_screen.dart
│   ├── detail_laporan_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   └── settings_screen.dart
│
└── services/
    ├── auth_service.dart
    ├── laporan_service.dart
    └── notification_service.dart
```

---

## 🚀 Getting Started

### Prerequisites

Make sure the following tools are installed:

* Flutter SDK
* Dart SDK
* Android Studio / VS Code
* Git
* Firebase project

Check Flutter installation:

```bash
flutter --version
```

### Clone Repository

```bash
git clone https://github.com/aryaptraderiz/Safezone.git
cd Safezone
```

### Install Dependencies

```bash
flutter pub get
```

### Run Application

```bash
flutter run
```

---

## 🔥 Firebase Configuration

SafeZone uses Firebase for:

* User authentication
* Crime reports
* Report verification
* Comments
* Application data

For configuring Firebase with another project, see:

```text
SETUP_FIREBASE.md
```

---

## 📦 Build Android

### Debug APK

```bash
flutter build apk --debug
```

### Release APK

```bash
flutter build apk --release
```

The generated APK will be available under:

```text
build/app/outputs/flutter-apk/
```

---

## 🔬 Research Scope

SafeZone is developed as an undergraduate thesis project focusing on the implementation of **GIS-based crime risk analysis and safe navigation**.

The research focuses on:

1. Spatial crime data processing.
2. Crime density estimation using KDE.
3. Crime risk visualization.
4. User-based crime reporting.
5. Risk-aware route recommendation.

The application is intended as a **decision-support tool** and does not guarantee that a recommended route is completely free from crime or danger.

---

## 🔮 Future Development

Potential future improvements include:

* Dynamic crime risk based on time.
* Time-decay mechanism for older incidents.
* More advanced Crime Risk Index calculation.
* Improved report validation.
* Integration with additional crime datasets.
* Personalized route preferences.
* Geofencing and safety alerts.
* More advanced GIS spatial analysis.
* Evaluation of routing algorithms using real-world datasets.

---

## 📚 Academic Context

**Project:** SafeZone
**Field:** Geographic Information System (GIS), Mobile Development, Spatial Analysis
**Method:** Kernel Density Estimation (KDE)
**Platform:** Mobile
**Program:** Informatics Engineering
**Institution:** Universitas Bakrie

---

## 👨‍💻 Author

**Arya Putra Aderiz**

Informatics Engineering
Universitas Bakrie

GitHub: [@aryaptraderiz](https://github.com/aryaptraderiz)

---

## 📄 License

This project is licensed under the MIT License.
