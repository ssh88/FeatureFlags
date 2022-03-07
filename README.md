# Feature Flagging

*NOTE: To focus on the key topic of feature flagging, the files in this repo have been simplified from the original implementation from the miPic app*

## Overview

When I was working on the miPic app, I was eager to implement a feature flagging tool. This was not only to be able to hide unfinished features behind a flag but also to show the rest of the team the power of feature flagging, from a/b testing to being able to remotely change things independently of a back-end.

I was an early adopter of Firebase remote config and was quickly able to build a basic feature flagging tool around it. In the past I had created a hidden debugging menu appropriately named Area 51, that was only accessible in the internal build of our app, which had various tools such as an environment selector, push notification tester and deep link tester.

Once feature flagging was possible in the app, I wrapped a UI around it and made it accessible inside our Area 51 debug menu. This allowed team members such as QAs and our product owner to be able to easily flag features on and off locally, without having to understand how to use the Firebase dashboard.

<p>
<img src="https://user-images.githubusercontent.com/3674185/156945551-0b8260df-64b0-4c5f-970c-fcb1e212c954.PNG" alt="T=Feature Flagging" height="200"/>  
 </p>  
   
 *miPic Feature Flag debug menu* 

The buy-in was immediate, very quickly I was being asked to leverage feature flagging more frequently, for example being able to show a Black Friday sales banner, where we could remotely update the text and promo codes.

Though extremely useful and powerful, the pain points of my original implementation became apparent very quickly. 
Adding a new feature flag involved various steps:

1. Add the new flag to Firebase remote config
2. Add the new flag constant to our feature flags constant file
3. Create a new Feature object in our feature flags array
4. Using the flag involved a verbose API (shown below)
```
guard FeatureFlagsManager.shared.string(for: FeatureFlagKey.applePayEnabled) else {
    return false
}
```

This was not a scalable solution, so I decided to try and automate the process as much as possible and clean up the API, which is the subject of this article.

## Implementation


### Scripting!!!

One of my favourite things about Swift is the ability to use it for scripting. My goal was to create a script to generate a few files which were mostly boilerplate code.

#### Config Files

The first step was to move away from hard-coding all of the flags and use a JSON config file, allowing us to configure our flags in one place, as shown below:

```
[
    {
        "key": "featureA",
        "description": "Cool feature A that is a bool",
        "value": false
    },
    {
        "key": "featureB",
        "description": "another cool feature, that is a string",
        "value": "use code SALE to get 25% off"
    }
]
```

In conjunction with this JSON file, I created a plist config file to declare the following properties

 | Key                       | Description           		   	    	        |
 | ------------------------- | ---------------------------------------- |
 |	inputFilePath			          |	file path of our feature flags json file | 
 |	outpuFilePath			          |	file path for the generated files        | 
 |	outpuFilename			          |	filename/prefix for generated file  	    | 


leveraging config files allowed me to build an isolated, flexible and reusable tool, which could be used by future projects or even open-sourced...when I had the time.


##### The Script

The next step was to create a script that could use these config files and generate `.swift` files that would be used inside the miPic codebase.

For the above example JSON file, the script outputs the following:

```
enum FeatureVariable: String {
    case featureA
    case featureB
}

protocol FeatureFlagManager {
    func string(for key: String) -> String
    func bool(for key: String) -> Bool
    func int(for key: String) -> Int
    func double(for key: String) -> Double
}

class FeatureFlags {
    let featureFlagManager: FeatureFlagManager

    init(featureFlagManager: FeatureFlagManager) {
        self.featureFlagManager = featureFlagManager
    }

    var featureA: Bool {
        featureFlagManager.bool(for: FeatureVariable.featureA.rawValue)
    }

    var featureB: String {
        featureFlagManager.string(for: FeatureVariable.featureB.rawValue)
    }
}
```

There are 3 key things that we now got for free without any manual intervention

1. `FeatureVariable`

An enum that has cases for each feature flag key

2. `FeatureFlagManager`

A protocol that a concrete feature flag manager should conform to, one that is backed by a feature flagging library, for example, Firebase remote config. It allows us to fetch values such as bools, strings or Ints.

3. `FeatureFlags`

Finally, our feature flagging concrete class that can be injected around our codebase enabling us to access feature flag variables.


In addition to these files being automatically generated, we now have vars with their getters implemented, meaning we can move away from this:
```
guard FeatureFlagsManager.shared.string(for: FeatureFlagKey.applePayEnabled) else {
    return false
}
```

and now use this

```
guard featureFlags.applePayEnabled else {
    return false
}
```

a more clean and friendly API. Also notice we are no longer using the shared instance of the `FeatureFlagManager` allowing this to be tested correctly!


##### pre-build phase

The next important step was to put this into an automation flow. The ideal candidate was using Xcode's build phases, where we can run the script at compile time. 
With this now in place our new workflow would be:

1. Add the new flag to firebase remote config
2. add the new flag to our feature flags JSON config file

Now we only need build to automatically get access to our feature flags in code!.

### Feature Flags Manager

From an implementation point, the only customisations needed are to create a concrete class for our `FeatureFlagManager` protocol

The feature flag manager is responsible for retrieving values in a given priority order which is as follows:

 - 1. First checks local cache (UserDefaults), as we may have updated a value using the debug menu. If one is found it takes priority.
 - 2. If there is no local value, we try to use the remote value. In this example, it would fetch the value from Firebase.
 - 3. If the remote value can not be found - may be due to no connection, this is the first launch, or there is no remote value for this key - we use the JSON config file as the fallback.

This is illustrated in the below flow diagram.

![Feature Flags Priority Flow](https://user-images.githubusercontent.com/3674185/156943997-db48b1e0-929b-41f5-94a2-d690ed937ef1.jpg)

Given the value could be of any type, we use a generic function to fetch the value from the priority order:

```
    func value<T>(for key: String, _ type: T.Type) -> T? {
        if let localValue = localValue(for: key) as? T {
            return localValue
        } else if let remoteValue = firebaseRemoteConfig.remoteData[key] as? T {
            return remoteValue
        } else if let defaultValue = defaultValue(for: key, T.self) {
            return defaultValue
        }
        return nil
    }
```

Here we are fetching the default fallback value from the JSON config file:

```
 func defaultValue<T>(for key: String, _ type: T.Type) -> T? {
        defaultValues
            .filter { $0.name == key }
            .compactMap {
                guard let value = $0.value as? T else { return nil }
                return value
            }
            .first
 }
```

#### Caching

A value is cached locally in `UserDefaults` via the feature flag debug menu, any time a value is changed in that menu we cache it so it takes priority order when read. The debug menu UI also can clear the cache, resetting the priority order back to the remote.

## Diagram
Below is an illustration of how the config files, script, generated files and debug menu interact.

![Feature Flagging](https://user-images.githubusercontent.com/3674185/156943989-707e739e-163e-4f09-941d-45b4cc533eec.jpg)


