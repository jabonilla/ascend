import React from 'react';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { NavigationContainer } from '@react-navigation/native';
import { StatusBar } from 'react-native';
import { store, persistor } from './store';
import AppNavigator from './navigation/AppNavigator';
import { ThemeProvider } from './theme/ThemeContext';
import { AuthProvider } from './contexts/AuthContext';
import { NotificationProvider } from './contexts/NotificationContext';
import SplashScreen from './screens/SplashScreen';
import Toast from 'react-native-toast-message';

const App = () => {
  return (
    <Provider store={store}>
      <PersistGate loading={<SplashScreen />} persistor={persistor}>
        <ThemeProvider>
          <AuthProvider>
            <NotificationProvider>
              <NavigationContainer>
                <StatusBar
                  barStyle="light-content"
                  backgroundColor="#4CAF50"
                  translucent={true}
                />
                <AppNavigator />
                <Toast />
              </NavigationContainer>
            </NotificationProvider>
          </AuthProvider>
        </ThemeProvider>
      </PersistGate>
    </Provider>
  );
};

export default App; 