import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  ScrollView,
  TouchableOpacity,
  Image,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { useTheme } from '../theme/ThemeContext';
import { useAuth } from '../contexts/AuthContext';

const { width, height } = Dimensions.get('window');

const OnboardingScreen = () => {
  const { theme } = useTheme();
  const { completeOnboarding } = useAuth();
  const [currentSlide, setCurrentSlide] = useState(0);

  const slides = [
    {
      id: 1,
      title: 'Welcome to RoundUp',
      subtitle: 'Your smart savings companion',
      description: 'Save money effortlessly by rounding up your everyday purchases and automatically investing the spare change.',
      icon: '💰',
    },
    {
      id: 2,
      title: 'Set Your Goals',
      subtitle: 'Dream big, save smart',
      description: 'Create specific savings goals for things you want to buy. Watch your progress grow with every transaction.',
      icon: '🎯',
    },
    {
      id: 3,
      title: 'Connect Your Bank',
      subtitle: 'Secure and seamless',
      description: 'Link your bank account securely with Plaid. We\'ll automatically round up your transactions.',
      icon: '🏦',
    },
    {
      id: 4,
      title: 'Social Savings',
      subtitle: 'Save together, achieve more',
      description: 'Join group goals with friends and family. Share your progress and celebrate together.',
      icon: '👥',
    },
    {
      id: 5,
      title: 'Ready to Start?',
      subtitle: 'Your financial future begins now',
      description: 'Join thousands of users who are already saving smarter with RoundUp.',
      icon: '🚀',
    },
  ];

  const handleNext = () => {
    if (currentSlide < slides.length - 1) {
      setCurrentSlide(currentSlide + 1);
    } else {
      handleComplete();
    }
  };

  const handleSkip = () => {
    handleComplete();
  };

  const handleComplete = async () => {
    try {
      await completeOnboarding();
    } catch (error) {
      console.error('Error completing onboarding:', error);
    }
  };

  const renderSlide = (slide) => (
    <View key={slide.id} style={styles.slide}>
      <View style={styles.iconContainer}>
        <Text style={styles.icon}>{slide.icon}</Text>
      </View>
      
      <Text style={[styles.title, { color: theme.colors.textPrimary }]}>
        {slide.title}
      </Text>
      
      <Text style={[styles.subtitle, { color: theme.colors.textSecondary }]}>
        {slide.subtitle}
      </Text>
      
      <Text style={[styles.description, { color: theme.colors.textSecondary }]}>
        {slide.description}
      </Text>
    </View>
  );

  const renderDots = () => (
    <View style={styles.dotsContainer}>
      {slides.map((_, index) => (
        <View
          key={index}
          style={[
            styles.dot,
            {
              backgroundColor: index === currentSlide 
                ? theme.colors.primary 
                : theme.colors.border,
            },
          ]}
        />
      ))}
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.background }]}>
      <ScrollView
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={(event) => {
          const slideIndex = Math.round(event.nativeEvent.contentOffset.x / width);
          setCurrentSlide(slideIndex);
        }}
        style={styles.scrollView}
      >
        {slides.map(renderSlide)}
      </ScrollView>

      <View style={styles.footer}>
        {renderDots()}
        
        <View style={styles.buttonContainer}>
          <TouchableOpacity
            style={styles.skipButton}
            onPress={handleSkip}
          >
            <Text style={[styles.skipButtonText, { color: theme.colors.textSecondary }]}>
              Skip
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.nextButton, { backgroundColor: theme.colors.primary }]}
            onPress={handleNext}
          >
            <Text style={[styles.nextButtonText, { color: theme.colors.textInverse }]}>
              {currentSlide === slides.length - 1 ? 'Get Started' : 'Next'}
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
  },
  slide: {
    width,
    height: height * 0.7,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 40,
  },
  iconContainer: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: 'rgba(76, 175, 80, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 40,
  },
  icon: {
    fontSize: 60,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 18,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 20,
  },
  description: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
    paddingHorizontal: 20,
  },
  footer: {
    paddingHorizontal: 40,
    paddingBottom: 40,
  },
  dotsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: 30,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginHorizontal: 4,
  },
  buttonContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  skipButton: {
    paddingVertical: 12,
    paddingHorizontal: 20,
  },
  skipButtonText: {
    fontSize: 16,
    fontWeight: '500',
  },
  nextButton: {
    paddingVertical: 12,
    paddingHorizontal: 30,
    borderRadius: 25,
    minWidth: 120,
    alignItems: 'center',
  },
  nextButtonText: {
    fontSize: 16,
    fontWeight: '600',
  },
});

export default OnboardingScreen; 