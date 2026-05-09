# CHAPTER 2: LITERATURE REVIEW

## 2.1 Introduction
The rapid evolution of the gig economy and digital labor platforms has necessitated more sophisticated methods for connecting service providers with consumers. Modern platforms are increasingly moving away from simple directory listings toward intelligent, location-aware, and secure ecosystems. This literature review examines recent studies and technological implementations that address the challenges of worker matching, verification, and real-time coordination.

## 2.2 Comparative Analysis of Existing Literature
The following table summarizes key research papers and their contributions to the field of digital hiring and AI-driven matching platforms.

### Table 1: Literature Review Summary

| Sr. No. | Author & Year | Techniques Used | Dataset / Evaluation | Key Findings / Accuracy |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Patel and Deshmukh (2023) | AI-based matching, skill and rating filters. | Not specified. | Improved matching efficiency but suffered from incomplete profiles and biased ratings. |
| 2 | Kaur and Reddy (2023) | Mobile hiring, GPS search, job posting tools. | Not specified. | App supported job discovery successfully but faced challenges with fake profiles. |
| 3 | Singh and Mehta (2024) | AML forecasting for manpower management. | Limited data. | Forecasting was effective, but accuracy dropped significantly with low data availability. |
| 4 | Arora and Kulkarni (2024) | Verification, ratings, and secure authentication. | Not specified. | Verification worked well, but rating bias and cold-start issues remained prevalent. |
| 5 | Thomas and Ibrahim (2025) | Deep learning and collaborative filtering. | Not specified. | High accuracy but required high computation and lacked real-time features. |

## 2.3 Synthesis and Research Gap
Based on the literature reviewed above, several critical observations can be made regarding the current state of labor-matching platforms:

1.  **Technological Sophistication vs. Performance**: While researchers like Thomas and Ibrahim (2025) have explored deep learning for high accuracy, the computational overhead remains a barrier for real-time mobile applications. There is a need for lightweight ML models that can run efficiently on mobile devices.
2.  **Trust and Reliability**: Verification systems (Arora and Kulkarni, 2024) and GPS-based discovery (Kaur and Reddy, 2023) have improved platform reliability. However, issues like "fake profiles" and "rating bias" still hinder user trust.
3.  **Real-time Dynamics**: Most existing models focus on matching based on historical data rather than live availability. The "cold-start" problem—where new workers or employers have no history—continues to be a challenge for matching algorithms.

## 2.4 How SmartConnect Bridges the Gap
The **SmartConnect** platform is designed to address these identified limitations through several innovative features:
*   **Lightweight ML Matching**: Instead of resource-intensive deep learning, we utilize optimized algorithms to provide accurate matches without compromising mobile performance.
*   **Live Availability Tracking**: Unlike static platforms, SmartConnect tracks worker availability in real-time, ensuring that "GPS search" results are actionable and current.
*   **Enhanced Verification & Escrow**: To counter the trust issues noted by Kaur and Reddy (2023), SmartConnect integrates secure authentication alongside an escrow-based payment system to protect both workers and contractors.
*   **Bias Mitigation**: By utilizing a multi-factor rating system combined with AI verification, the platform aims to reduce the rating bias identified in earlier studies.
