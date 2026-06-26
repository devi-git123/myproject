# Smart Student Budget Tracker

##  Project Overview
The **Smart Student Budget Tracker** is a comprehensive financial management application specifically designed to help university students monitor their income, manage daily expenses, and track personal savings goals. Navigating student life introduces unique financial pressures; this platform serves as an intuitive, data-driven solution ensuring students can systematically record transactions, visualize categorical spending, and maintain healthy financial habits.


## Objectives
* **Expense & Income Tracking:** Provide a seamless interface for logging recurring allowances, salaries, and daily multi-category expenditures (e.g., Food, Transport, Utilities, Education).
* **Goal-Oriented Savings:** Enable students to set up, track, and visualize progress towards distinct financial goals.
* **Database Relational Integrity:** Enforce structured, relational standard operations (SQL constraints, explicit foreign keys) to safely secure multi-user transaction histories.



##  Tech Stack & Architecture

### Frontend & Core Application
* **Framework:** Flutter (Dart) — For a smooth, cross-platform mobile user experience.
* **State Management & Backend Services:** Firebase (Authentication & Cloud Firestore Integration).

### Database Engine (Relational Design Blueprint)
* **DBMS:** MySQL / Relational Database Engine
* **Core Relational Structures:**
  * `Users`: Tracks identification parameters and specific functional currencies (`currencyCode`).
  * `Categories`: Houses customizable expenditure buckets dynamically tied to unique users (`uid`).
  * `Transactions`: Manages atomic lines of transactional balances mapping decimal values against relational categories and user keys.

