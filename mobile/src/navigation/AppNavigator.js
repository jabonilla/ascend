import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useTheme } from '@react-navigation/native';

// Import screens
import SplashScreen from '../screens/SplashScreen';
import OnboardingScreen from '../screens/OnboardingScreen';
import LoginScreen from '../screens/auth/LoginScreen';
import RegisterScreen from '../screens/auth/RegisterScreen';
import ForgotPasswordScreen from '../screens/auth/ForgotPasswordScreen';
import EmailVerificationScreen from '../screens/auth/EmailVerificationScreen';

// Main app screens
import HomeScreen from '../screens/main/HomeScreen';
import GoalsScreen from '../screens/main/GoalsScreen';
import TransactionsScreen from '../screens/main/TransactionsScreen';
import SocialScreen from '../screens/main/SocialScreen';
import ProfileScreen from '../screens/main/ProfileScreen';

// Goal screens
import GoalDetailScreen from '../screens/goals/GoalDetailScreen';
import CreateGoalScreen from '../screens/goals/CreateGoalScreen';
import EditGoalScreen from '../screens/goals/EditGoalScreen';
import GoalContributionsScreen from '../screens/goals/GoalContributionsScreen';

// Transaction screens
import TransactionDetailScreen from '../screens/transactions/TransactionDetailScreen';
import RoundupHistoryScreen from '../screens/transactions/RoundupHistoryScreen';

// Social screens
import FriendProfileScreen from '../screens/social/FriendProfileScreen';
import GroupGoalDetailScreen from '../screens/social/GroupGoalDetailScreen';
import CreateGroupGoalScreen from '../screens/social/CreateGroupGoalScreen';
import SocialFeedScreen from '../screens/social/SocialFeedScreen';

// Banking screens
import ConnectBankScreen from '../screens/banking/ConnectBankScreen';
import BankAccountsScreen from '../screens/banking/BankAccountsScreen';

// Payment screens
import PaymentMethodsScreen from '../screens/payment/PaymentMethodsScreen';
import AddPaymentMethodScreen from '../screens/payment/AddPaymentMethodScreen';

// Settings screens
import SettingsScreen from '../screens/settings/SettingsScreen';
import NotificationSettingsScreen from '../screens/settings/NotificationSettingsScreen';
import PrivacySettingsScreen from '../screens/settings/PrivacySettingsScreen';
import SecuritySettingsScreen from '../screens/settings/SecuritySettingsScreen';

const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();

// Main tab navigator
const MainTabNavigator = () => {
  const { theme } = useTheme();

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName;

          switch (route.name) {
            case 'Home':
              iconName = 'home';
              break;
            case 'Goals':
              iconName = 'flag';
              break;
            case 'Transactions':
              iconName = 'receipt';
              break;
            case 'Social':
              iconName = 'people';
              break;
            case 'Profile':
              iconName = 'person';
              break;
            default:
              iconName = 'circle';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: theme.colors.primary,
        tabBarInactiveTintColor: theme.colors.textSecondary,
        tabBarStyle: {
          backgroundColor: theme.colors.background,
          borderTopColor: theme.colors.border,
          borderTopWidth: 1,
          paddingBottom: 5,
          paddingTop: 5,
          height: 60,
        },
        headerShown: false,
      })}
    >
      <Tab.Screen 
        name="Home" 
        component={HomeScreen}
        options={{ title: 'Home' }}
      />
      <Tab.Screen 
        name="Goals" 
        component={GoalsScreen}
        options={{ title: 'Goals' }}
      />
      <Tab.Screen 
        name="Transactions" 
        component={TransactionsScreen}
        options={{ title: 'Transactions' }}
      />
      <Tab.Screen 
        name="Social" 
        component={SocialScreen}
        options={{ title: 'Social' }}
      />
      <Tab.Screen 
        name="Profile" 
        component={ProfileScreen}
        options={{ title: 'Profile' }}
      />
    </Tab.Navigator>
  );
};

// Main app navigator
const AppNavigator = () => {
  const { isAuthenticated, isLoading } = useSelector(state => state.auth);
  const { isOnboardingComplete } = useSelector(state => state.auth);

  if (isLoading) {
    return <SplashScreen />;
  }

  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: false,
      }}
    >
      {!isAuthenticated ? (
        // Auth stack
        <>
          {!isOnboardingComplete && (
            <Stack.Screen name="Onboarding" component={OnboardingScreen} />
          )}
          <Stack.Screen name="Login" component={LoginScreen} />
          <Stack.Screen name="Register" component={RegisterScreen} />
          <Stack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
          <Stack.Screen name="EmailVerification" component={EmailVerificationScreen} />
        </>
      ) : (
        // Main app stack
        <>
          <Stack.Screen name="MainTabs" component={MainTabNavigator} />
          
          {/* Goal screens */}
          <Stack.Screen name="GoalDetail" component={GoalDetailScreen} />
          <Stack.Screen name="CreateGoal" component={CreateGoalScreen} />
          <Stack.Screen name="EditGoal" component={EditGoalScreen} />
          <Stack.Screen name="GoalContributions" component={GoalContributionsScreen} />
          
          {/* Transaction screens */}
          <Stack.Screen name="TransactionDetail" component={TransactionDetailScreen} />
          <Stack.Screen name="RoundupHistory" component={RoundupHistoryScreen} />
          
          {/* Social screens */}
          <Stack.Screen name="FriendProfile" component={FriendProfileScreen} />
          <Stack.Screen name="GroupGoalDetail" component={GroupGoalDetailScreen} />
          <Stack.Screen name="CreateGroupGoal" component={CreateGroupGoalScreen} />
          <Stack.Screen name="SocialFeed" component={SocialFeedScreen} />
          
          {/* Banking screens */}
          <Stack.Screen name="ConnectBank" component={ConnectBankScreen} />
          <Stack.Screen name="BankAccounts" component={BankAccountsScreen} />
          
          {/* Payment screens */}
          <Stack.Screen name="PaymentMethods" component={PaymentMethodsScreen} />
          <Stack.Screen name="AddPaymentMethod" component={AddPaymentMethodScreen} />
          
          {/* Settings screens */}
          <Stack.Screen name="Settings" component={SettingsScreen} />
          <Stack.Screen name="NotificationSettings" component={NotificationSettingsScreen} />
          <Stack.Screen name="PrivacySettings" component={PrivacySettingsScreen} />
          <Stack.Screen name="SecuritySettings" component={SecuritySettingsScreen} />
        </>
      )}
    </Stack.Navigator>
  );
};

export default AppNavigator; 