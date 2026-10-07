//
//  PassApplicationGitWrapper.m
//  PassApplicationGitWrapper
//
//  Created by amine on 28/06/2022.
//  Copyright © 2022 com.intech-consulting. All rights reserved.
//

#import "Libgit2Module.h"
#import "git2.h"

// 61,915
// 26,535

__attribute__((constructor))
static void PassApplicationGitWrapperInit(void) {
    git_libgit2_init();
}
