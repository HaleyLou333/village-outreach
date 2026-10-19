# Village Outreach
A smart cities mutual-aid mobile application designed to help neighbors request support, offer assistance, and discover nearby community resources.
This README summarizes the project architecture, team roles, development workflow, and milestone scope as defined in the Software Design Document.

---

## Team Members & Roles
| Team Member | Primary Role | Email |
|-------------|--------------|-------|
| **Haley Eason** | Project Lead / Full-Stack | haeason@student.fullsail.edu |
| **Matthew Bakken** | Frontend / UI-UX | matt96bakken@gmail.com |
| **Arianna Miller-Paul** | AI Developer | anmillerpaul@student.fullsail.edu |
| **Eric Joel Reyes Rivera (Atomic Misfit)** | Backend Developer | Ejreyesrivera@gmail.com |

---

## Project Purpose
Village Outreach is a community support platform that enables users to:

- Post help requests
- Offer assistance
- Communicate safely
- Discover nearby resources
- Coordinate mutual aid within their neighborhood

---

## Goals & Non-Goals

### **Goals**
- Make local help easier to find and organize
- Provide safe communication between requester and helper
- Support community resource discovery

### **Non-Goals**
- Emergency response or crisis intervention
- Peer-to-peer payments
- Direct client-side database access
- AI-dependent workflows
- Background checks

---

## System Architecture

Village Outreach uses a mobile-first architecture:

### **Frontend**
- Flutter mobile app
- Android-first prototype
- UI built with Nunito, Inter, and Raleway
- Soft forest green, pale orange, + off-white brand palette

### **Backend**
- FastAPI (Python)
- Business logic, authentication checks, and data access
- AI integration endpoints

### **Database**
- PostgreSQL (Supabase or hosted PostgreSQL)
- Entities: User, HelpRequest, Offer, Message, Resource, Report, Organization

### **Authentication**
- Firebase Authentication

### **Maps Provider**
- Google Maps

### ** AI Provider**
- Google Cloud Natural Language

---

## Core Features (MVP)

### **Minimum Viable Product**
- Account creation & sign-in
- Create help requests (category, description, urgency, location)
- Browse nearby requests
- Offer help
- Resource map
- Messaging
- Safety reporting
- Database persistence for all core entities

---

## User Experience Overview

Village Outreach priorities:

- Warm, calm, community-focused UI
- Clear navigation
- Accessibility (readable text, simple flows)
- Fast posting and simple communication

Primary screens include:
- Sign In / Account
- Home / Nearby Requests
- Create Request
- Request Details
- Resource Map
- Messages
- Profile / Safety

---

### Entity Relationship Model (ERD)

**Entities:**
- User
- HelpRequest
- Offer
- Message
- Resource
- Report
- Organization

---

## Backend API Surface

Initial API groups:

- **Health** - backend status
- **Users** - profile read/update
- **Requests** - create/list/read/update
- **Offers** - create/review
- **Messages** - send/load conversations
- **Resources** - list/filter
- **Reports** - create safety reports
- **AI** - category/resource suggestions

---

## Development Environment 

### **Tools**
Git/Github
VS Code
Android Studio
Flutter SDK
Python / FastAPI
PostgreSQL
Figma (UI/UX)
Firebase Console

---

## Branching & Workflow

### **Branch Types**
- `main` — stable milestone builds  
- `develop` — integrated development  
- `feature/<name>` — individual features  
- `release/<milestone>` — optional stabilization  
- `hotfix/<name>` — urgent fixes

### **Pull Request Rules**
- Test locally before review  
- No credentials committed  
- Clear commit messages  
- Reviewer approval required

---

## Testing Plan

| Area | Focus | Owner |
|------|--------|--------|
| Backend/API | Validation, permissions, DB behavior | Eric / Haley |
| Frontend | Navigation, forms, layout | Matt |
| AI | Output quality, fallback behavior | Arianna / Haley |
| End-to-end | Full user flows | Whole team |
| Outside testing | Scenario-based testing | Whole team |

---

## Repository Structure

The repo separates:

- `/frontend` — Flutter  
- `/backend` — FastAPI  
- `/ai` — preprocessing + model integration  
- `/docs` — design docs, architecture, wireframes

---

## AI Model Integration

- Provider: Google Cloud Natural Language  
- Used for:  
  - Category prediction  
  - Sentiment cues  
  - Lightweight recommendations  
- No PII sent to AI provider  
- AI features are optional and non-blocking

---

## Open Team Decisions

| Decision | Owner |
|----------|--------|
| Flutter/Android versions | Matt |
| Python/FastAPI/PostgreSQL versions | Eric / Haley |
| Maps provider | Matt / Haley |
| AI provider/model | Arianna / Haley |

---

## Roadmap
- **Alpha:** Notifications, filters, organizations, photos, multilingual support  
- **Beta:** AI suggestions, accessibility, reputation indicators, resource guides  
- **Version 2.0:** Donations, background checks, municipal partnerships
